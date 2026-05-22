extends HBoxContainer

@onready var _count_label: Label = $CountLabel

var _count := 0


func _ready() -> void:
	_update_label()


func increment() -> void:
	_count += 1
	_update_label()


func _update_label() -> void:
	_count_label.text = str(_count)
