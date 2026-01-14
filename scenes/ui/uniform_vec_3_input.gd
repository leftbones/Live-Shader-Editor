class_name UniformVec3Input
extends HBoxContainer

@onready var label: Label = $Label
@onready var input_x: LineEdit = $InputX
@onready var input_y: LineEdit = $InputY
@onready var input_z: LineEdit = $InputZ

var value:
	get:
		return Vector3(
			input_x.text.to_float(),
			input_y.text.to_float(),
			input_z.text.to_float()
		)

signal value_changed(value: Vector3)


func _ready() -> void:
	input_x.text_changed.connect(func(new_value: String):
		value_changed.emit(label.text, value)
	)
	input_y.text_changed.connect(func(new_value: String):
		value_changed.emit(label.text, value)
	)
	input_z.text_changed.connect(func(new_value: String):
		value_changed.emit(label.text, value)
	)


# Initialize the UI element with the uniform name and value
func init(uniform_name: String, uniform_value: Vector3) -> void:
	label.text = uniform_name
	input_x.text = str(uniform_value.x)
	input_y.text = str(uniform_value.y)
	input_z.text = str(uniform_value.z)