extends Node

@onready var data: ConfigFile = ConfigFile.new()

var default_dir: String = ""
var ui_scale: float = 1.0
var autosave: bool = false


# Attempt to load the config file on startup
func _ready() -> void:
	print("User data stored at: " + OS.get_user_data_dir())
	load_config()


# Update the config file with the current settings
func save_config() -> void:
	data.set_value("General", "default_dir", default_dir)
	data.set_value("Interface", "ui_scale", ui_scale)
	data.set_value("Editor", "autosave", autosave)

	var err: int = data.save("user://config.cfg")
	if err == OK:
		_apply_config()
		print("Config file saved and applied successfully.")
	else:
		push_warning("Failed to save config file!")


# Load the config file settings into the current settings
func load_config() -> void:
	var err: int = data.load("user://config.cfg")
	if err == OK:
		default_dir = data.get_value("General", "default_dir", default_dir)
		ui_scale = data.get_value("Interface", "ui_scale", ui_scale)
		autosave = data.get_value("Editor", "autosave", autosave)
		_apply_config()
		print("Config file loaded and applied successfully.")
	else:
		push_warning("Failed to load config file, using defaults.")
		save_config()


# Apply the config settings to the project
func _apply_config() -> void:
	get_window().content_scale_factor = ui_scale
