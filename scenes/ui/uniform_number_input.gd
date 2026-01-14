class_name UniformNumberInput
extends HBoxContainer

@onready var label: Label = $Label
@onready var input: LineEdit = $Input

var value:
	get:
		return input.text

signal value_changed(value: String)


func _ready() -> void:
	input.text_changed.connect(func(new_value: String):
		value_changed.emit(label.text, new_value)
	)


# Initialize the UI element with the uniform name and value
func init(uniform_name: String, uniform_value: String) -> void:
	label.text = uniform_name
	input.text = uniform_value
