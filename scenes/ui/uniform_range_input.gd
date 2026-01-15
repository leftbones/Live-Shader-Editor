class_name UniformRangeInput
extends HBoxContainer

@onready var label: Label = $Label
@onready var input: HSlider = $Input

@onready var value_label: Label = $ValueLabel

var value:
	get:
		return input.value

signal value_changed(value: String)


func _ready() -> void:
	input.value_changed.connect(func(new_value: float):
		value_changed.emit(label.text, str(new_value))
		value_label.text = str(new_value)
	)


# Initialize the UI element with the uniform name and value
func init(uniform_name: String, uniform_value: String, min_value: String, max_value: String, step_value: String) -> void:
	label.text = uniform_name
	input.value = float(uniform_value)
	value_label.text = uniform_value
	input.min_value = float(min_value)
	input.max_value = float(max_value)
	input.step = float(step_value)
