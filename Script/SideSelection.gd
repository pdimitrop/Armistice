extends Control

@onready var select_side_label: Label = $Label
@onready var back: TextureButton = $Back
@onready var entente_icon: TextureButton = $EntenteIcon
@onready var central_icon: TextureButton = $CentralIcon
@onready var play: Button = $Play

enum Side {
	ENTENTE,
	CENTRAL
}

signal side_selected(side)

var current_side : int = -1

func _ready():
	select_side_label.text = tr("SELECT_SIDE")

	var entente_callable := Callable(self, "_on_entente_pressed")
	if not entente_icon.pressed.is_connected(entente_callable):
		entente_icon.pressed.connect(entente_callable)

	var central_callable := Callable(self, "_on_central_pressed")
	if not central_icon.pressed.is_connected(central_callable):
		central_icon.pressed.connect(central_callable)

	var back_callable := Callable(self, "_on_back_pressed")
	if not back.pressed.is_connected(back_callable):
		back.pressed.connect(back_callable)

func _on_entente_pressed():
	current_side = Side.ENTENTE
	select_side_label.text = tr("ENTENTE_BUTTON")
	entente_icon.grab_focus()
	central_icon.release_focus()
	emit_signal("side_selected", Side.ENTENTE)
	play.show()

func _on_central_pressed():
	current_side = Side.CENTRAL
	select_side_label.text = tr("CENTRAL_BUTTON")
	central_icon.grab_focus()
	entente_icon.release_focus()
	emit_signal("side_selected", Side.CENTRAL)
	play.show()

func _on_back_pressed():
	play.hide()
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")

func _on_play_pressed() -> void:
	if current_side == -1:
		push_warning("No side selected; cannot start.")
		return

	const BRIDGE_NAME := "SceneBridge"
	var root := get_tree().get_root()
	var bridge: Node = null

	if root.has_node(BRIDGE_NAME):
		bridge = root.get_node(BRIDGE_NAME)
	else:
		bridge = Node.new()
		bridge.name = BRIDGE_NAME
		root.add_child(bridge)

	bridge.set_meta("selected_side", current_side)

	get_tree().change_scene_to_file("res://Scenes/Loading.tscn")


# Scene-connected stubs; the real handlers are wired in _ready().
func _on_entente_icon_pressed() -> void:
	pass


func _on_central_icon_pressed() -> void:
	pass
