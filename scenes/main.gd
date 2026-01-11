class_name Main
extends Control

const LOG_PATH: String = "user://logs/godot.log"
const MESSAGE_FINISH: String = "COMPILE FINISHED"
const MESSAGE_ERROR: String = "SHADER ERROR: "

const SYNTAX_TYPES: PackedStringArray = ["void", "bool", "int", "float", "vec2", "vec3", "vec4", "mat2", "mat3", "mat4", "sampler2D", "samplerCube"]
const SYNTAX_KEYWORDS: PackedStringArray = ["if", "else", "for", "white", "do", "return", "break", "continue", "discard"]
const SYNTAX_BUILTINS: PackedStringArray = ["texture", "mix", "dot", "cross", "normalize", "length", "distance", "reflect", "sin", "cos", "tan", "abs", "min", "max", "clamp", "step", "smoothstep"]
const SYNTAX_SHADERS: PackedStringArray = ["shader_type", "render_mode", "uniform", "varying", "attribute", "const", "in", "out", "inout"]

@onready var code_editor: CodeEdit = %CodeEditor
@onready var status_label: RichTextLabel = %StatusLabel
@onready var fps_label: RichTextLabel = %FPSLabel
@onready var preview_container: VBoxContainer = %PreviewContainer
@onready var shader_properties: VBoxContainer = %ShaderProperties

# Preview
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


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	# Connect signals
	code_editor.text_changed.connect(_start_update_timer)
	preview_container.gui_input.connect(_on_preview_gui_input)

	# Setup shader preview
	active_preview = %Preview3D

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
	if event is InputEventMouseButton and event.is_pressed():
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			active_preview.camera.fov = max(25, active_preview.camera.fov - 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			active_preview.camera.fov = min(100, active_preview.camera.fov + 5.0)


# Start the timer to update the shader after a delay (to avoid excessive recompilations)
func _start_update_timer() -> void:
	update_timer = 0


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


# Parse the shader code to extract uniform variables
func _get_shader_uniforms() -> Array[Dictionary]:
	var uniforms: Array[Dictionary] = []
	var shader: Shader = active_preview.shader_material.shader

	var lines: PackedStringArray = code_editor.text.split("\n")
	var ignore: PackedStringArray = ["=", ":"]
	for line in lines:
		line = line.strip_edges()
		if line.begins_with("uniform"):
			var parts: PackedStringArray = []
			line = line.replace("uniform", "").strip_edges()
			var idx: int = 0;
			while idx < line.length() - 1:
				if line[idx] == " ":
					idx += 1
				else:
					var token: String = ""
					while line[idx] != " ":
						token += line[idx]
						idx += 1
						if idx >= line.length() - 1:
							break

					if not ignore.has(token):
						parts.append(token)
			
			print(parts)

	return uniforms


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

	var uniforms: Array[Dictionary] = _get_shader_uniforms()

	
