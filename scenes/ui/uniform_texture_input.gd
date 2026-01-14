class_name UniformTextureInput
extends HBoxContainer

@onready var label: Label = $Label
@onready var input: TextureButton = $TextureButton

@onready var default_texture: Texture2D = preload("res://icon.svg")

signal value_changed


func _ready() -> void:
	input.pressed.connect(func():
		value_changed.emit(label.text, input.texture_normal)
	)

	input.texture_normal = default_texture


# Initialize the UI element with the uniform name and value
func init(uniform_name: String, uniform_value: Vector4) -> void:
	label.text = uniform_name
	# input.color = Color(uniform_value.x, uniform_value.y, uniform_value.z)
