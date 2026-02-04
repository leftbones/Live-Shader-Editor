extends MenuBar

@onready var file_menu: PopupMenu = %File
@onready var options_menu: PopupMenu = %Options
@onready var help_menu: PopupMenu = %Help
@onready var load_shader_dialog: FileDialog = %LoadShaderDialog
@onready var save_shader_dialog: FileDialog = %SaveShaderDialog


func _ready() -> void:
	# Connect signals
	file_menu.index_pressed.connect(_handle_file_menu_option)
	options_menu.index_pressed.connect(_handle_options_menu_option)
	help_menu.index_pressed.connect(_handle_help_menu_option)

	# Set menu checks based on config
	options_menu.set_item_checked(0, Config.autosave)
	options_menu.set_item_checked(1, Config.ui_scale > 1.0)


func _handle_file_menu_option(index: int) -> void:
	match index:
		0: # New
			pass
		1: # Open
			pass
		2: # Save
			pass
		3: # Save As
			pass
		4: # Exit
			# TODO: Prompt to save unsaved work before exiting
			get_tree().quit()


func _handle_options_menu_option(index: int) -> void:
	match index:
		0: # Autosave
			options_menu.set_item_checked(0, not options_menu.is_item_checked(0))
			Config.autosave = options_menu.is_item_checked(0)
			Config.save_config()
		1: # Large UI
			options_menu.set_item_checked(1, not options_menu.is_item_checked(1))
			Config.ui_scale = 2.0 if options_menu.is_item_checked(1) else 1.0
			Config.save_config()
		2: # Reload Config
			Config.load_config()


func _handle_help_menu_option(index: int) -> void:
	match index:
		0: # Repo
			OS.shell_open("https://github.com/leftbones/live-shader-editor")
		1: # Issues
			OS.shell_open("https://github.com/leftbones/live-shader-editor/issues")
