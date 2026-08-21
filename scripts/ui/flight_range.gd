extends Node3D

const METERS_TO_FEET: float = 3.28084
const RANGE_LOOK_TARGET := Vector3(0.0, 2.0, -45.0)

@onready var disc = $Disc
@onready var release_point: Marker3D = $ReleasePoint
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var side_camera: Camera3D = $SideCamera
@onready var chase_camera: Camera3D = $ChaseCamera
@onready var overhead_camera: Camera3D = $OverheadCamera
@onready var speed_input: SpinBox = $UI/Panel/Controls/SpeedInput
@onready var spin_input: SpinBox = $UI/Panel/Controls/SpinInput
@onready var release_angle_input: SpinBox = $UI/Panel/Controls/ReleaseAngleInput
@onready var launch_angle_input: SpinBox = $UI/Panel/Controls/LaunchAngleInput
@onready var nose_angle_input: SpinBox = $UI/Panel/Controls/NoseAngleInput
@onready var camera_angle_select: OptionButton = $UI/Panel/Controls/CameraAngleSelect
@onready var distance_value: Label = $UI/MeasurementPanel/Readout/DistanceValue
@onready var status_value: Label = $UI/MeasurementPanel/Readout/StatusValue

var release_position := Vector3.ZERO
var has_landed := false
var active_camera_index := 0


func _ready() -> void:
	overview_camera.look_at(RANGE_LOOK_TARGET, Vector3.UP)
	side_camera.look_at(RANGE_LOOK_TARGET, Vector3.UP)
	chase_camera.look_at(Vector3(0.0, 2.0, -25.0), Vector3.UP)
	overhead_camera.look_at(RANGE_LOOK_TARGET, Vector3.UP)
	_set_active_camera(camera_angle_select.selected)


func _physics_process(_delta: float) -> void:
	if active_camera_index == 2 and disc.is_flying:
		chase_camera.global_position = disc.global_position + Vector3(
			0.0,
			3.5,
			10.0,
		)
		chase_camera.look_at(disc.global_position, Vector3.UP)


func _on_camera_angle_select_item_selected(index: int) -> void:
	_set_active_camera(index)


func _set_active_camera(index: int) -> void:
	active_camera_index = index
	overview_camera.current = index == 0
	side_camera.current = index == 1
	chase_camera.current = index == 2
	overhead_camera.current = index == 3


func _on_throw_button_pressed() -> void:
	release_position = release_point.global_position
	has_landed = false
	distance_value.text = "Ground distance: measuring…"
	status_value.text = "In flight"

	var throw := ThrowParameters.new(
		speed_input.value,
		spin_input.value,
		release_angle_input.value,
		launch_angle_input.value,
		nose_angle_input.value,
	)

	disc.launch(release_point.global_transform, throw)


func _on_reset_button_pressed() -> void:
	has_landed = false
	disc.reset(release_point.global_position)
	distance_value.text = "Ground distance: —"
	status_value.text = "Ready"


func _on_disc_flight_segment_advanced(
	previous_position: Vector3,
	next_position: Vector3,
) -> void:
	if has_landed:
		return

	if previous_position.y > 0.0 and next_position.y <= 0.0:
		var travel_fraction := previous_position.y / (
			previous_position.y - next_position.y
		)
		var impact_position := previous_position.lerp(
			next_position,
			travel_fraction,
		)
		var horizontal_offset := impact_position - release_position
		var distance_meters := Vector2(
			horizontal_offset.x,
			horizontal_offset.z,
		).length()

		has_landed = true
		disc.stop_at(impact_position)
		distance_value.text = "Ground distance: %.1f m (%.0f ft)" % [
			distance_meters,
			distance_meters * METERS_TO_FEET,
		]
		status_value.text = "Ground impact — flight stopped"
