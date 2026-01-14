class_name UniformVec2Input
extends HBoxContainer

@onready var label: Label = $Label
@onready var input_x: LineEdit = $InputX
@onready var input_y: LineEdit = $InputY

var value:
	get:
		return Vector2(
			input_x.text.to_float(),
			input_y.text.to_float(),
		)

signal value_changed(value: Vector2)


func _ready() -> void:
	input_x.text_changed.connect(func(new_value: String):
		value_changed.emit(label.text, value)
	)
	input_y.text_changed.connect(func(new_value: String):
		value_changed.emit(label.text, value)
	)


# Initialize the UI element with the uniform name and value
func init(uniform_name: String, uniform_value: Vector2) -> void:
	label.text = uniform_name
	input_x.text = str(uniform_value.x)
	input_y.text = str(uniform_value.y)