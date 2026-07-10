class_name CentralAnimLoader
extends Node
# Injects the outfield animations into the instanced Central model's AnimationPlayer.

const BASE := "res://Assets/Characters/Central/CentralAnimated/"

const EXTRA_ANIMS := {
	"jog forward":       BASE + "Jog Forward.fbx",
	"dribble":           BASE + "Dribble.fbx",
	"standing":          BASE + "Receive Soccerball.fbx",
	"kick soccerball 1": BASE + "Soccer Penalty Kick.fbx",
	"kick soccerball 2": BASE + "Soccer Pass.fbx",
}

func _ready() -> void:
	var ap: AnimationPlayer = get_parent().find_child("AnimationPlayer", true, false)
	if not ap:
		push_error("CentralAnimLoader: no AnimationPlayer found under %s" % get_parent().name)
		return

	var lib: AnimationLibrary = _get_default_library(ap)
	if not lib:
		return

	_rename_base_anim(lib, "offensive idle")
	_copy_anims(lib, EXTRA_ANIMS)
	_set_loop_modes(lib)


# Mixamo clips import with loop_mode=NONE; loop jog/dribble or they freeze
# mid-stride. Kicks stay one-shot so animation_finished still fires.
func _set_loop_modes(lib: AnimationLibrary) -> void:
	const LOOPING := [&"jog forward", &"dribble"]
	for anim_name: StringName in lib.get_animation_list():
		if anim_name == &"RESET":
			continue
		var anim := lib.get_animation(anim_name)
		anim.loop_mode = Animation.LOOP_LINEAR if anim_name in LOOPING else Animation.LOOP_NONE


func _get_default_library(ap: AnimationPlayer) -> AnimationLibrary:
	if ap.has_animation_library(""):
		return ap.get_animation_library("")
	var libs := ap.get_animation_library_list()
	if libs.is_empty():
		push_error("CentralAnimLoader: AnimationPlayer has no libraries on %s" % get_parent().name)
		return null
	return ap.get_animation_library(libs[0])


func _rename_base_anim(lib: AnimationLibrary, target: StringName) -> void:
	for anim_name: StringName in lib.get_animation_list():
		if anim_name == &"RESET":
			continue
		if anim_name == target:
			return
		var anim := lib.get_animation(anim_name)
		lib.add_animation(target, anim)
		lib.remove_animation(anim_name)
		return


func _copy_anims(lib: AnimationLibrary, map: Dictionary) -> void:
	for target_name: String in map:
		var scene: PackedScene = load(map[target_name])
		if not scene:
			push_warning("CentralAnimLoader: cannot load %s" % map[target_name])
			continue
		var inst: Node = scene.instantiate()
		var src_ap: AnimationPlayer = inst.find_child("AnimationPlayer", true, false)
		if src_ap:
			var names := src_ap.get_animation_list()
			for src_name: StringName in names:
				if src_name == &"RESET":
					continue
				if lib.has_animation(target_name):
					lib.remove_animation(target_name)
				var copy: Animation = src_ap.get_animation(src_name).duplicate()
				# "standing" is only ever held on one frame, so it needs no in-place strip.
				if target_name != "standing":
					_make_in_place(copy)
				lib.add_animation(target_name, copy)
				break
		else:
			push_warning("CentralAnimLoader: no AnimationPlayer in %s" % map[target_name])
		inst.free()


# Freeze the horizontal (X/Z) motion baked into the root track so the clip plays
# in place instead of walking the model away from the player node. Keeps the Y bob.
static func _make_in_place(anim: Animation) -> void:
	var root_track := -1
	var best_range := 0.0
	for t in anim.get_track_count():
		if anim.track_get_type(t) != Animation.TYPE_POSITION_3D:
			continue
		var kc := anim.track_get_key_count(t)
		if kc < 2:
			continue
		var min_x := INF
		var max_x := -INF
		var min_z := INF
		var max_z := -INF
		for k in kc:
			var v: Vector3 = anim.track_get_key_value(t, k)
			min_x = minf(min_x, v.x)
			max_x = maxf(max_x, v.x)
			min_z = minf(min_z, v.z)
			max_z = maxf(max_z, v.z)
		var rng := (max_x - min_x) + (max_z - min_z)
		if rng > best_range:
			best_range = rng
			root_track = t
	if root_track == -1 or best_range < 0.1:
		return
	var v0: Vector3 = anim.track_get_key_value(root_track, 0)
	for k in anim.track_get_key_count(root_track):
		var v: Vector3 = anim.track_get_key_value(root_track, k)
		v.x = v0.x
		v.z = v0.z
		anim.track_set_key_value(root_track, k, v)
