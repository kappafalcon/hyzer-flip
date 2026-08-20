extends CharacterBody3D

@export var move_speed: float = 6.0
@export var mouse_sensitivity: float = 0.002

@onready var first_person_pivot: Node3D = $Cameras/FirstPersonPivot
@onready var third_person_pivot: Node3D = $Cameras/ThirdPersonPivot

@export var disc_scene: PackedScene

@onready var throw_origin: Marker3D = $ThrowOrigin
@onready var release_point = $ReleasePoint

@onready var speed_input = $UI/Panel/Controls/SpeedInput
@onready var spin_input = $UI/Panel/Controls/SpinInput
@onready var release_angle_input = $UI/Panel/Controls/ReleaseAngleInput
@onready var launch_angle_input = $UI/Panel/Controls/LaunchAngleInput
@onready var nose_angle_input: SpinBox = $UI/Panel/Controls/NoseAngleInput


var camera_pitch: float = 0.0

func _physics_process(_delta: float) -> void:
	var move_input := _read_move_input()
	_apply_movement(move_input)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
func _spawn_disc() -> void:
	if disc_scene == null:
		return

	var disc := disc_scene.instantiate()

	get_tree().current_scene.add_child(disc)

	
	var throw = ThrowParameters.new(
		speed_input.value,
		spin_input.value,
		release_angle_input.value,
		launch_angle_input.value,
		nose_angle_input.value
	)

	disc.launch(release_point.global_transform, throw)
		
func _read_move_input() -> Vector2:
	return Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_backward",
	)


func _apply_movement(move_input: Vector2) -> void:
	var local_direction := Vector3(
		move_input.x,
		0.0,
		move_input.y,
	)

	var move_direction := global_transform.basis * local_direction

	velocity.x = move_direction.x * move_speed
	velocity.z = move_direction.z * move_speed

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if event.is_action_pressed("throw_disc"):
		_spawn_disc()
		
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)

		camera_pitch -= event.relative.y * mouse_sensitivity
		camera_pitch = clamp(
			camera_pitch,
			deg_to_rad(-80.0),
			deg_to_rad(80.0),
		)

		first_person_pivot.rotation.x = camera_pitch
		third_person_pivot.rotation.x = camera_pitch
