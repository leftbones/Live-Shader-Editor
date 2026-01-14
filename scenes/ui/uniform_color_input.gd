class_name UniformColorInput
extends HBoxContainer

@onready var label: Label = $Label
@onready var input: ColorPickerButton = $ColorPickerButton

signal value_changed(value: Color)


func _ready() -> void:
	input.color_changed.connect(func(new_value: Color):
		value_changed.emit(label.text, new_value)
	)

	var picker: ColorPicker = input.get_picker()
	picker.edit_intensity = false
	picker.can_add_swatches = false
	picker.sampler_visible = false
	picker.presets_visible = false


# Initialize the UI element with the uniform name and value
func init(uniform_name: String, uniform_value: Vector3) -> void:
	label.text = uniform_name
	input.color = Color(uniform_value.x, uniform_value.y, uniform_value.z)