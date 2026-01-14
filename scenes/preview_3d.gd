# TODO:
# - Add settings for light intensity/color for the main light and ambient light
# - Add texture preview support (apply a texture to the preview mesh)

@tool
class_name Preview3D
extends Node3D

@onready var camera: Camera3D = $Camera
@onready var environment: Environment = $Environment.environment
@onready var light: DirectionalLight3D = $Light
@onready var cube_mesh: MeshInstance3D = $CubeMesh
@onready var quad_mesh: MeshInstance3D = $QuadMesh

var shader_material: ShaderMaterial
var shader: Shader

# Preview Mesh
@export_enum("Cube", "Quad")
var preview_mesh_type: int = 0:
	set(value):
		preview_mesh_type = value
		_set_preview_mesh()

var preview_mesh: MeshInstance3D

# Animation
@export_group("Animation")
@export var animate: bool = false
@export_range(-1.0, 1.0, 0.1) var animate_speed_x: float = 1.0
@export_range(-1.0, 1.0, 0.1) var animate_speed_y: float = 1.0
@export_tool_button("Reset Rotation", "Callable")
var reset_button_action: Callable = reset_preview

# Defaults
var _default_camera_fov: float = 50.0
var _default_mesh_rotation: Vector2 = Vector2(0, 0)
var _default_animation_speed: Vector2 = Vector2(0.5, 0.5)


# Called when the node enters the scene tree for the first time
func _ready() -> void:
	_default_mesh_rotation = Vector2(
		cube_mesh.rotation_degrees.x,
		cube_mesh.rotation_degrees.y,
	)

	await get_tree().process_frame

	shader_material = ShaderMaterial.new()
	_set_preview_mesh()


# Called once every frame
func _process(delta: float) -> void:
	if preview_mesh == null or Engine.is_editor_hint(): return

	if animate and (animate_speed_x != 0.0 or animate_speed_y != 0.0):
		var rotation_delta = Vector2(
			animate_speed_x * 0.5 * delta,
			animate_speed_y * 0.5 * delta,
		)
		preview_mesh.rotate_x(rotation_delta.x)
		preview_mesh.rotate_y(rotation_delta.y)


# Reset the preview mesh to its default properties
func reset_preview() -> void:
	if preview_mesh == null: return
	preview_mesh.rotation_degrees = Vector3(_default_mesh_rotation.x, _default_mesh_rotation.y, 0)
	camera.fov = _default_camera_fov


# Set the preview mesh based on the selected type
func _set_preview_mesh() -> void:
	reset_preview()

	cube_mesh.visible = false
	quad_mesh.visible = false

	match preview_mesh_type:
		0:
			preview_mesh = cube_mesh
			cube_mesh.visible = true
		1:
			preview_mesh = quad_mesh
			quad_mesh.visible = true

	preview_mesh.material_override = shader_material


# Toggle the animation state
func toggle_animation(enabled: bool) -> void:
	animate = enabled
