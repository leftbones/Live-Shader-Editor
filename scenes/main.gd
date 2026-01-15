class_name Main
extends Control

const LOG_PATH: String = "user://logs/godot.log"
const MESSAGE_FINISH: String = "COMPILE FINISHED"
const MESSAGE_ERROR: String = "SHADER ERROR: "

const SYNTAX_TYPES: PackedStringArray = ["void", "bool", "int", "float", "vec2", "vec3", "vec4", "sampler2D"]
const SYNTAX_KEYWORDS: PackedStringArray = ["if", "else", "for", "white", "do", "return", "break", "continue", "discard"]
const SYNTAX_BUILTINS: PackedStringArray = ["texture", "mix", "dot", "cross", "normalize", "length", "distance", "reflect", "sin", "cos", "tan", "abs", "min", "max", "clamp", "step", "smoothstep"]
const SYNTAX_SHADERS: PackedStringArray = ["shader_type", "render_mode", "uniform", "varying", "attribute", "const", "in", "out", "inout"]

@onready var uniform_number_input_scene: PackedScene = preload("res://scenes/ui/uniform_number_input.tscn")
@onready var uniform_range_input_scene: PackedScene = preload("res://scenes/ui/uniform_range_input.tscn")
@onready var uniform_vec2_input_scene: PackedScene = preload("res://scenes/ui/uniform_vec_2_input.tscn")
@onready var uniform_vec3_input_scene: PackedScene = preload("res://scenes/ui/uniform_vec_3_input.tscn")
@onready var uniform_vec4_input_scene: PackedScene = preload("res://scenes/ui/uniform_vec_4_input.tscn")
@onready var uniform_color_input_scene: PackedScene = preload("res://scenes/ui/uniform_color_input.tscn")
@onready var uniform_texture_input_scene: PackedScene = preload("res://scenes/ui/uniform_texture_input.tscn")

@onready var code_editor: CodeEdit = %CodeEditor
@onready var status_label: RichTextLabel = %StatusLabel
@onready var fps_label: RichTextLabel = %FPSLabel
@onready var preview_container: VBoxContainer = %PreviewContainer
@onready var viewport_settings: VBoxContainer = %ViewportSettings
@onready var animate_checkbox: CheckBox = %AnimateCheckBox
@onready var reset_preview_button: Button = %ResetPreviewButton
@onready var shader_properties: VBoxContainer = %ShaderProperties
@onready var load_shader_dialog: FileDialog = %LoadShaderDialog
@onready var save_shader_dialog: FileDialog = %SaveShaderDialog
@onready var file_menu: PopupMenu = %File
@onready var options_menu: PopupMenu = %Options
@onready var help_menu: PopupMenu = %Help

# Preview
var parser: Parser = Parser.new()
var active_preview: Variant = null

# Compilation
var update_timeout: float = 0.5;
var update_timer: float = 0.0;

var log_file: FileAccess
var compile_error_line: int = 0
var compile_error_regex: RegEx = RegEx.new()

var current_fps: float = 0.0

# Syntax Highlighting
var syntax_highlighter: CodeHighlighter = CodeHighlighter.new()
var colors: Dictionary[String, Color] = {
	"transparent": Color("ffffff", 0.0),
	"error_line_bg": Color("ff3333", 0.6),
	"error_status_fg": Color("ff6666"),
	"syntax_symbol": Color("abc9ff"),
	"syntax_keyword": Color("ff7085"),
	"syntax_function": Color("8fffdb"),
	"syntax_type": Color("42ffc2"),
	"syntax_comment": Color("808080"),
	"syntax_number": Color("a1ffe0"),
	"syntax_string": Color("ffeda1"),
}

# File Operations
var save_path: String = ""


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Setup shader preview
	active_preview = %Preview3D
	viewport_settings.modulate.a = 0.0

	# Setup regex error parsing
	compile_error_regex.compile("E\\s+(\\d+)->")

	# Setup syntax highlighting
	syntax_highlighter.symbol_color = colors["syntax_symbol"]
	syntax_highlighter.function_color = colors["syntax_function"]
	syntax_highlighter.member_variable_color = colors["syntax_type"]
	syntax_highlighter.number_color = colors["syntax_number"]

	syntax_highlighter.add_color_region("//", "", colors["syntax_comment"])
	syntax_highlighter.add_color_region("/*", "*/", colors["syntax_comment"])

	for keyword in SYNTAX_TYPES:
		syntax_highlighter.add_keyword_color(keyword , colors["syntax_type"])

	for keyword in SYNTAX_KEYWORDS:
		syntax_highlighter.add_keyword_color(keyword, colors["syntax_keyword"])

	for keyword in SYNTAX_BUILTINS:
		syntax_highlighter.add_keyword_color(keyword , colors["syntax_function"])

	for keyword in SYNTAX_SHADERS:
		syntax_highlighter.add_keyword_color(keyword , colors["syntax_symbol"])

	code_editor.syntax_highlighter = syntax_highlighter

	# Connect signals
	code_editor.text_changed.connect(_start_update_timer)
	preview_container.gui_input.connect(_on_preview_gui_input)
	preview_container.mouse_entered.connect(func():
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(viewport_settings, "modulate:a", 1.0, 0.2)
		active_preview.hovered = true
	)
	preview_container.mouse_exited.connect(func():
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(viewport_settings, "modulate:a", 0.0, 0.2)
		active_preview.hovered = false
	)
	animate_checkbox.toggled.connect(active_preview.toggle_animation)
	reset_preview_button.pressed.connect(active_preview.reset_preview)

	# Wait until everything is ready before the first compile
	await get_tree().process_frame
	_compile_shader()


# Called every frame, 'delta' is the elapsed time since the previous frame
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	# Update FPS display
	current_fps = Engine.get_frames_per_second()

	if current_fps <= 15:
		fps_label.modulate = Color(1.0, 0.0, 0.0)
	elif current_fps <= 30:
		fps_label.modulate = Color(1.0, 0.6, 0.0)
	elif current_fps <= 45:
		fps_label.modulate = Color(1.0, 1.0, 0.0)
	elif current_fps > 45:
		fps_label.modulate = Color(1.0, 1.0, 1.0, 0.3)

	fps_label.text = "FPS: %d" % current_fps

	# Automatically compile shader after a delay with no input
	if update_timer < update_timeout:
		update_timer += delta
		if update_timer >= update_timeout:
			_compile_shader()


# Handle mouse input on the 3D preview (for zooming)
func _on_preview_gui_input(event: InputEvent) -> void:
	if not active_preview.hovered:
		return

	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			active_preview.camera.fov = max(25, active_preview.camera.fov - 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active_preview.camera.fov = min(100, active_preview.camera.fov + 5.0)


# Start the timer to update the shader after a delay (to avoid excessive recompilations)
func _start_update_timer() -> void:
	update_timer = 0


# Set a shader parameter on the active preview's shader material
func _set_shader_parameter(uniform_name: String, uniform_value: Variant) -> void:
	active_preview.shader_material.set_shader_parameter(uniform_name, uniform_value)


# Set the status message in the UI
func _set_status_message(message: String) -> void:
	status_label.text = message


# Return the contents of the shader log files for error checking
func _get_shader_logs() -> PackedStringArray:
	if not log_file:
		log_file = FileAccess.open(LOG_PATH, FileAccess.READ)
		if log_file == null:
			print("ERROR: Failed to open log file")
			return []

	var lines: PackedStringArray = log_file.get_as_text().split("\n")
	return lines


# Check if there are any shader compilation errors
func _check_compile_errors() -> void:
	# Reset the compile error state
	if compile_error_line > -1:
		code_editor.set_line_background_color(compile_error_line, colors["transparent"])
		compile_error_line = -1

	# Find errors in the log file
	var lines: PackedStringArray = _get_shader_logs()

	for i in range(lines.size() - 1, 0, -1):
		var line: String = lines[i]

		if line == MESSAGE_FINISH:
			break

		if line.contains(MESSAGE_ERROR):
			_set_status_message("ERROR: %s" % line.replace(MESSAGE_ERROR, ""))

		var result: RegExMatch = compile_error_regex.search(line)
		if result:
			compile_error_line = result.get_string(1).to_int() - 1
			code_editor.set_line_background_color(compile_error_line, colors["error_line_bg"])
			status_label.modulate = colors["error_status_fg"]
			break

	if compile_error_line == -1:
		_set_status_message("OK")
		status_label.modulate = Color(1.0, 1.0, 1.0)


# Attempt to compile the shader code from the code editor
func _compile_shader() -> void:
	# Update the shader material
	var shader: Shader = Shader.new()
	shader.code = code_editor.text
	active_preview.shader_material.shader = shader

	# Check for compilation errors
	_check_compile_errors()
	print(MESSAGE_FINISH)

	# Update the shader properties list 
	for child in shader_properties.get_children():
		child.queue_free()

	var uniforms: Array[Parser.Uniform] = parser.get_shader_uniforms(code_editor.text)
	for uniform in uniforms:
		#
		# Float
		if uniform.type == "float":
			if uniform.hint.begins_with("hint_range"):
				var uniform_input: UniformRangeInput = uniform_range_input_scene.instantiate()
				shader_properties.add_child(uniform_input)

				var range_values: PackedStringArray = uniform.hint.replace("hint_range(", "").replace(")", "").split(",")

				uniform_input.init(uniform.name, uniform.value, range_values[0], range_values[1], range_values[2])

				uniform_input.value_changed.connect(_set_shader_parameter)
			else:
				var uniform_input: UniformNumberInput = uniform_number_input_scene.instantiate()
				shader_properties.add_child(uniform_input)

				uniform_input.init(uniform.name, uniform.value)

				uniform_input.value_changed.connect(_set_shader_parameter)

		#
		# Vec2
		elif uniform.type == "vec2":
			var uniform_input: UniformVec2Input = uniform_vec2_input_scene.instantiate()
			shader_properties.add_child(uniform_input)

			var vec2_values: PackedStringArray = uniform.value.replace("vec2(", "").replace(")", "").split(",")
			if vec2_values.size() != 2:
				vec2_values = [vec2_values[0], vec2_values[0]]

			uniform_input.init(uniform.name, Vector2(
				vec2_values[0].to_float(),
				vec2_values[1].to_float()
			))

			uniform_input.value_changed.connect(_set_shader_parameter)

		#
		# Vec3 (+ source_color hint)
		elif uniform.type == "vec3":
			var uniform_input := uniform_color_input_scene.instantiate() if uniform.hint == "source_color" else uniform_vec3_input_scene.instantiate()
			shader_properties.add_child(uniform_input)

			var vec3_values: PackedStringArray = uniform.value.replace("vec3(", "").replace(")", "").split(",")
			if vec3_values.size() != 3:
				vec3_values = [vec3_values[0], vec3_values[0], vec3_values[0]]

			uniform_input.init(uniform.name, Vector3(
				vec3_values[0].to_float(),
				vec3_values[1].to_float(),
				vec3_values[2].to_float()
			))

			uniform_input.value_changed.connect(_set_shader_parameter)

		#
		# Vec4
		elif uniform.type == "vec4":
			var uniform_input: UniformVec4Input = uniform_vec4_input_scene.instantiate()
			shader_properties.add_child(uniform_input)

			var vec4_values: PackedStringArray = uniform.value.replace("vec4(", "").replace(")", "").split(",")
			if vec4_values.size() != 4:
				vec4_values = [vec4_values[0], vec4_values[0], vec4_values[0], vec4_values[0]]

			uniform_input.init(uniform.name, Vector4(
				vec4_values[0].to_float(),
				vec4_values[1].to_float(),
				vec4_values[2].to_float(),
				vec4_values[3].to_float()
			))

			uniform_input.value_changed.connect(_set_shader_parameter)

		#
		# Sampler2D
		elif uniform.type == "sampler2D":
			var uniform_input: UniformTextureInput = uniform_texture_input_scene.instantiate()
			shader_properties.add_child(uniform_input)

			uniform_input.init(uniform.name) # I don't think it's possible to set textures in shader code directly, so there's no value to parse here

			uniform_input.value_changed.connect(_set_shader_parameter)
		
		#
		# Other
		else:
			var label: Label = Label.new()
			label.text = "%s (%s) = %s" % [uniform.name, uniform.type, uniform.value]
			shader_properties.add_child(label)
