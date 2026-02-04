class_name Parser

const TYPES: PackedStringArray = ["void", "bool", "int", "float", "vec2", "vec3", "vec4", "sampler2D"]
const HINTS: PackedStringArray = ["hint_enum", "hint_range", "source_color", "hint_default_white", "hint_default_black"]

const DEFAULT_TYPE_VALUES: Dictionary[String, String] = {
	"bool": "false",
	"int": "0",
	"float": "0.0",
	"vec2": "vec2(0.0)",
	"vec3": "vec3(0.0)",
	"vec4": "vec4(0.0)",
	"sampler2D": "vec4(0.0)",
}

# Helper class to represent a uniform and its hint and value
class Uniform:
	var type: String
	var name: String
	var hint: String
	var value: String

	func _init(_type: String, _name: String, _hint: String, _value: String) -> void:
		type = _type
		name = _name
		hint = _hint
		value = _value


# Parse the shader code to extract uniform variables and their properties
func get_shader_uniforms(shader_code: String) -> Array[Uniform]:
	var uniforms: Array[Uniform] = []

	# Split the code into lines
	var lines: PackedStringArray = shader_code.split("\n")
	for line in lines:
		# Look for lines that declare uniforms
		if line.begins_with("uniform"):
			# Remove the "uniform" keyword, strip spaces from commas, remove unnecessary symbols (=, :, and ;)
			line = line.replace("uniform", "").replace(", ", ",").replace("=", "").replace(":", "").replace(";", "").strip_edges()
			var parts: PackedStringArray = line.split(" ", false)
			# print(parts)

			if parts.size() == 4: # type, name, hint, and value are present
				var uniform_type: String = parts[0]
				var uniform_name: String = parts[1]
				var uniform_hint: String = parts[2]
				var uniform_value: String = parts[3]
				uniforms.append(Uniform.new(uniform_type, uniform_name, uniform_hint, uniform_value))
			elif parts.size() == 3: # type, name, and either hint or value are present
				var uniform_type: String = parts[0]
				var uniform_name: String = parts[1]
				var third_part: String = parts[2]

				# Determine if the third part is a hint or a value
				if HINTS.has(third_part):
					var default_value: String = DEFAULT_TYPE_VALUES.get(uniform_type, "")

					# Handle specific hints that require special default values
					if third_part == "hint_default_white":
						default_value = "vec4(1.0)"
					elif third_part == "hint_default_black":
						default_value = "vec4(0.0)"

					uniforms.append(Uniform.new(uniform_type, uniform_name, third_part, default_value))
				else:
					uniforms.append(Uniform.new(uniform_type, uniform_name, "", third_part))

	return uniforms
