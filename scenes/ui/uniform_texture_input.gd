class_name UniformTextureInput
extends HBoxContainer

@onready var label: Label = $Label
@onready var texture_preview: TextureRect = %TexturePreview
@onready var menu_button: MenuButton = %MenuButton
@onready var file_dialog: FileDialog = $FileDialog

signal value_changed


func _ready() -> void:
	file_dialog.file_selected.connect(_on_file_selected)

	menu_button.get_popup().id_pressed.connect(func(id: int):
		match id:
			0:
				file_dialog.popup_centered()
			1:
				texture_preview.texture = null
				value_changed.emit(label.text, null)
		)


# Initialize the UI element with the uniform name and value
func init(uniform_name: String) -> void:
	label.text = uniform_name


# Handle file selection from the FileDialog
func _on_file_selected(path: String) -> void:
	var img := Image.new()
	var err := img.load(path)
	if err == OK:
		var img_tex: ImageTexture = ImageTexture.create_from_image(img)
		texture_preview.texture = img_tex
		value_changed.emit(label.text, img_tex)
	else:
		push_error("Failed to load image from path: %s" % path)
