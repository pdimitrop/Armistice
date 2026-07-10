extends Node

const BASE := "res://Assets/Characters/Central/CentralAnimated/"

const EXTRA_ANIMS := {
	"jog forward":       BASE + "Goalkeeper Sidestep.fbx",
	"kick soccerball 1": BASE + "Goalkeeper Drop Kick.fbx",
	"kick soccerball 2": BASE + "Goalkeeper Pass.fbx",
}

func _ready() -> void:
	var ap: AnimationPlayer = get_parent().find_child("AnimationPlayer", true, false)
	if not ap:
		push_error("GoalkeeperAnimLoader: no AnimationPlayer found under %s" % get_parent().name)
		return

	var lib: AnimationLibrary = _get_default_library(ap)
	if not lib:
		return

	_rename_base_anim(lib, "offensive idle")
	_copy_anims(lib, EXTRA_ANIMS)
	_set_loop_modes(lib)


# Mixamo clips import with loop_mode=NONE; loop idle and the sidestep or the
# keeper freezes mid-pose. Kick/pass stay one-shot.
func _set_loop_modes(lib: AnimationLibrary) -> void:
	const LOOPING := [&"offensive idle", &"jog forward"]
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
		push_error("GoalkeeperAnimLoader: AnimationPlayer has no libraries on %s" % get_parent().name)
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
			push_warning("GoalkeeperAnimLoader: cannot load %s" % map[target_name])
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
				CentralAnimLoader._make_in_place(copy)
				lib.add_animation(target_name, copy)
				break
		else:
			push_warning("GoalkeeperAnimLoader: no AnimationPlayer in %s" % map[target_name])
		inst.free()
