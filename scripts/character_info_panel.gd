extends PanelContainer

@onready var _name_label: Label = %NameLabel
@onready var _description_label: Label = %DescriptionLabel


func _ready() -> void:
	hide_panel()


func show_character(character: CharacterBody3D) -> void:
	_name_label.text = character.get_display_name()
	_description_label.text = character.get_description_text()
	visible = true


func hide_panel() -> void:
	visible = false
