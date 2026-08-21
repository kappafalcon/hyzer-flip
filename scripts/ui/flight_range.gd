extends Node3D

const METERS_TO_FEET: float = 3.28084
const RANGE_LOOK_TARGET := Vector3(0.0, 2.0, -45.0)

@export var available_disc_data: Array[DiscData] = []

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
@onready var disc_select: OptionButton = $UI/Panel/Controls/DiscSelect
@onready var camera_angle_select: OptionButton = $UI/Panel/Controls/CameraAngleSelect
@onready var distance_value: Label = $UI/MeasurementPanel/Readout/DistanceValue
@onready var status_value: Label = $UI/MeasurementPanel/Readout/StatusValue

var release_position := Vector3.ZERO
var has_landed := false
var active_camera_index := 0
var active_throw: ThrowParameters


func _ready() -> void:
	_populate_disc_select()
	overview_camera.look_at(RANGE_LOOK_TARGET, Vector3.UP)
	side_camera.look_at(RANGE_LOOK_TARGET, Vector3.UP)
	chase_camera.look_at(Vector3(0.0, 2.0, -25.0), Vector3.UP)
	overhead_camera.look_at(RANGE_LOOK_TARGET, Vector3.UP)
	_set_active_camera(camera_angle_select.selected)


func _populate_disc_select() -> void:
	disc_select.clear()
	for disc_data in available_disc_data:
		if disc_data == null:
			continue
		var disc_name := disc_data.resource_name
		if disc_name.is_empty():
			disc_name = disc_data.resource_path.get_file().get_basename()
		disc_select.add_item(disc_name)

	var selected_index := available_disc_data.find(disc.disc_data)
	if selected_index < 0 and not available_disc_data.is_empty():
		selected_index = 0
		disc.disc_data = available_disc_data[selected_index]
	if selected_index >= 0:
		disc_select.select(selected_index)


func _on_disc_select_item_selected(index: int) -> void:
	if disc.is_flying or index < 0 or index >= available_disc_data.size():
		return

	disc.disc_data = available_disc_data[index]
	disc.reset(release_point.global_position)
	has_landed = false
	distance_value.text = "Ground distance: —"
	status_value.text = "Selected %s" % disc_select.get_item_text(index)


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
	if disc.is_flying:
		return

	release_position = release_point.global_position
	has_landed = false
	disc_select.disabled = true
	distance_value.text = "Ground distance: measuring…"
	status_value.text = "In flight"

	active_throw = ThrowParameters.new(
		speed_input.value,
		spin_input.value,
		release_angle_input.value,
		launch_angle_input.value,
		nose_angle_input.value,
	)

	disc.launch(release_point.global_transform, active_throw)


func _on_reset_button_pressed() -> void:
	has_landed = false
	disc.reset(release_point.global_position)
	active_throw = null
	disc_select.disabled = false
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
		disc_select.disabled = false
		distance_value.text = "Ground distance: %.1f m (%.0f ft)" % [
			distance_meters,
			distance_meters * METERS_TO_FEET,
		]
		var disc_name: String = disc.disc_data.resource_name
		if disc_name.is_empty():
			disc_name = disc.disc_data.resource_path.get_file().get_basename()
		print("Flight Range | disc: %s | release: %.0f mph, %.0f rpm, %.1f° hyzer, %.1f° launch, %.1f° nose | distance: %.1f m (%.0f ft) | time: %.2f s | spin: %.0f rpm" % [
			disc_name,
			active_throw.speed / 0.44704,
			active_throw.spin_rate * 60.0 / TAU,
			active_throw.release_angle,
			active_throw.launch_angle,
			active_throw.nose_angle,
			distance_meters,
			distance_meters * METERS_TO_FEET,
			disc.flight_state.elapsed_time,
			disc.flight_state.spin_rate * 60.0 / TAU,
		])
		status_value.text = "Ground impact — %.2f s, AoA %.1f°, roll %.1f°/s" % [
			disc.flight_state.elapsed_time,
			rad_to_deg(disc.flight_state.angle_of_attack),
			rad_to_deg(disc.flight_state.roll_rate),
		]
