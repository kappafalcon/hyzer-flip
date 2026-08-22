extends CharacterBody3D

signal arcade_throw_requested(command: ArcadeThrowCommand)

@export var move_speed: float = 6.0
@export var mouse_sensitivity: float = 0.002
@export_range(0.1, 3.0, 0.1, "suffix:s") var charge_duration_seconds: float = 1.0
@export_range(-90.0, 90.0, 0.1, "suffix:degrees") var release_bank_degrees: float = 0.0
@export_range(1.0, 30.0, 0.1, "suffix:degrees") var release_bank_step_degrees: float = 5.0
@export_range(-15.0, 15.0, 0.1, "suffix:degrees") var launch_pitch_offset_degrees: float = 0.0

@onready var first_person_pivot: Node3D = $Cameras/FirstPersonPivot
@onready var third_person_pivot: Node3D = $Cameras/ThirdPersonPivot
@onready var power_indicator: ProgressBar = $UI/PowerIndicator
@onready var release_angle_label: Label = $UI/ReleaseAngleLabel

@onready var throw_origin: Marker3D = $ThrowOrigin


var camera_pitch: float = 0.0
var charge_started_at_msec := -1

func _physics_process(_delta: float) -> void:
	var move_input := _read_move_input()
	_apply_movement(move_input)
	if charge_started_at_msec >= 0:
		var charge_elapsed_seconds := (
			Time.get_ticks_msec() - charge_started_at_msec
		) / 1000.0
		power_indicator.value = clampf(
			charge_elapsed_seconds / charge_duration_seconds,
			0.0,
			1.0,
		)


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _request_arcade_throw(charge: float) -> void:
	var camera_forward := -third_person_pivot.global_transform.basis.z
	var horizontal_forward := Vector3(camera_forward.x, 0.0, camera_forward.z)
	var aim_pitch_degrees := rad_to_deg(asin(clampf(camera_forward.y, -1.0, 1.0)))
	var command := ArcadeThrowCommand.new(
		throw_origin.global_position,
		horizontal_forward,
		charge,
		release_bank_degrees,
		clampf(
			aim_pitch_degrees + launch_pitch_offset_degrees,
			-30.0,
			30.0,
		),
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_RIGHT,
	)
	if not command.is_valid():
		push_error("Player rejected invalid arcade throw command.")
		return
	arcade_throw_requested.emit(command)

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

	var release_bank_change := 0.0
	if event.is_action_pressed("release_hyzer"):
		release_bank_change += release_bank_step_degrees
	if event.is_action_pressed("release_anhyzer"):
		release_bank_change -= release_bank_step_degrees
	if not is_zero_approx(release_bank_change):
		release_bank_degrees = clampf(
			release_bank_degrees + release_bank_change,
			-90.0,
			90.0,
		)
		var angle_name := "Flat"
		if release_bank_degrees > 0.0:
			angle_name = "Hyzer"
		elif release_bank_degrees < 0.0:
			angle_name = "Anhyzer"
		release_angle_label.text = "%s %d°" % [
			angle_name,
			roundi(absf(release_bank_degrees)),
		]

	if event.is_action_pressed("throw_charge"):
		charge_started_at_msec = Time.get_ticks_msec()
		power_indicator.value = 0.0
		power_indicator.show()
	if event.is_action_released("throw_charge"):
		if charge_started_at_msec >= 0:
			var charge_elapsed_seconds := (
				Time.get_ticks_msec() - charge_started_at_msec
			) / 1000.0
			var charge := clampf(charge_elapsed_seconds / charge_duration_seconds, 0.0, 1.0)
			charge_started_at_msec = -1
			power_indicator.hide()
			_request_arcade_throw(charge)

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
