extends CanvasLayer

func _ready() -> void:
	$Label.text = tr("PAUSE_LABEL")
	$MainMenuButton.text = tr("MAIN_MENU")
	$ScoreLabel.text = ""

func set_score(entente: int, central: int) -> void:
	$ScoreLabel.text = "%s  %d — %d  %s" % [
		tr("ENTENTE_BUTTON"), entente, central, tr("CENTRAL_BUTTON")
	]

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game") and get_tree().paused:
		get_tree().paused = false
		visible = false
		get_viewport().set_input_as_handled()

func _on_main_menu_pressed() -> void:
	var music := get_node_or_null("/root/BgMusic") as AudioStreamPlayer2D
	if music:
		music.volume_db = 0.0
		music.play()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
