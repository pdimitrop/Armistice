extends Control

@onready var animation_intro = $AnimationPlayer

func _ready():
	animation_intro.play("Black_in")
	get_tree().create_timer(3).timeout.connect(black_out)

func black_out():
	animation_intro.play("Black_out")
	get_tree().create_timer(3).timeout.connect(start_menu_scene)

func start_menu_scene():
	get_tree().change_scene_to_file("res://Scenes/Intro1.tscn")

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		skip_to_main_menu()

func skip_to_main_menu():
	get_tree().change_scene_to_file("res://Scenes/MainMenu.tscn")
