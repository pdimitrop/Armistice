extends Control

var progress = []
var sceneName
var scene_load_status = 0

var selected_side: int = -1
const BRIDGE_NAME := "SceneBridge"

func _ready():
	var root := get_tree().get_root()
	if root.has_node(BRIDGE_NAME):
		var bridge := root.get_node(BRIDGE_NAME)
		selected_side = bridge.get_meta("selected_side", -1)
		bridge.queue_free()
	else:
		selected_side = -1

	var state := Node.new()
	state.name = "GameState"
	state.set_meta("selected_side", selected_side)
	root.add_child(state)

	sceneName = "res://Scenes/Main.tscn"
	ResourceLoader.load_threaded_request(sceneName)

func _process(_delta: float) -> void:
	scene_load_status = ResourceLoader.load_threaded_get_status(sceneName, progress)
	%countDown.text = str(floor(progress[0] * 100)) + "%"

	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		var newScene = ResourceLoader.load_threaded_get(sceneName)
		get_tree().change_scene_to_packed(newScene)
