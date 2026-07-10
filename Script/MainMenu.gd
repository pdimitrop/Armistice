extends Control

@onready var language_button: OptionButton = $Language
@onready var start_button: Button = $Start
@onready var flag_button: TextureButton = $Flag
@onready var help_button: Button = $Help

var language_locales := {
	"English": "en",
	"Ελληνικά": "el",
	"Deutsch": "de",
	"Français": "fr",
	"Italiano": "it",
	"Español": "es",
	"Русский язык": "ru",
	"Српски језик": "sr",
	"Srpskohrvatski jezik": "sh",
	"Български език": "bg"
}

var flags := {
	"en": "res://Assets/img/flags/en.png",
	"el": "res://Assets/img/flags/el.png",
	"de": "res://Assets/img/flags/de.png",
	"fr": "res://Assets/img/flags/fr.png",
	"it": "res://Assets/img/flags/it.png",
	"es": "res://Assets/img/flags/es.png",
	"ru": "res://Assets/img/flags/ru.png",
	"sr": "res://Assets/img/flags/sr.png",
	"sh": "res://Assets/img/flags/sh.png",
	"bg": "res://Assets/img/flags/bg.png"
}

var current_language: String = "English"

func _ready() -> void:
	for lang_name in language_locales:
		language_button.add_item(lang_name)
		var idx := language_button.item_count - 1
		language_button.set_item_metadata(idx, language_locales[lang_name])
	
	var current_locale := TranslationServer.get_locale()
	var selected_index := 0

	for i in range(language_button.item_count):
		if language_button.get_item_metadata(i) == current_locale:
			selected_index = i
			break

	language_button.select(selected_index)
	update_start_button()
	update_flag(selected_index)

func _on_exit_pressed() -> void:
	get_tree().quit()


func _on_start_pressed() -> void:
	var sideSelection = load("res://Scenes/SideSelection.tscn")
	get_tree().change_scene_to_packed(sideSelection)

func _on_language_item_selected(index: int) -> void:
	current_language = language_button.get_item_text(index)
	var locale_code: String = language_button.get_item_metadata(index)
	TranslationServer.set_locale(locale_code)
	update_start_button()
	update_flag(index)

func update_start_button() -> void:
	start_button.text = tr("START_BUTTON")

func _on_help_pressed() -> void:
	var help_scene = load("res://Scenes/Help.tscn")
	get_tree().change_scene_to_packed(help_scene)

func update_flag(index: int) -> void:
	var locale_code: String = language_button.get_item_metadata(index)
	var flag_path := "res://Assets/img/flags/%s.png" % locale_code
	var flag_tex := load(flag_path) as Texture2D
	if flag_tex:
		flag_button.texture_normal = flag_tex
	else:
		print("Flag missing: ", flag_path)
