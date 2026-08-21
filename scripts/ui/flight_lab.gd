extends Node3D

const METERS_TO_FEET := 3.28084

@onready var disc = $Disc
@onready var release_point = $ReleasePoint
@onready var speed_input: SpinBox = $UI/Panel/Controls/SpeedInput
@onready var spin_input: SpinBox = $UI/Panel/Controls/SpinInput
@onready var release_angle_input: SpinBox = $UI/Panel/Controls/ReleaseAngleInput
@onready var launch_angle_input: SpinBox = $UI/Panel/Controls/LaunchAngleInput
@onready var nose_angle_input: SpinBox = $UI/Panel/Controls/NoseAngleInput


var release_position := Vector3.ZERO
var has_landed := false


func _ready() -> void:
	disc.flight_segment_advanced.connect(_on_disc_flight_segment_advanced)


func _on_throw_button_pressed() -> void:
	release_position = release_point.global_position
	has_landed = false
	var throw = ThrowParameters.new(
		speed_input.value,
		spin_input.value,
		release_angle_input.value,
		launch_angle_input.value,
		nose_angle_input.value
	)

	disc.launch(release_point.global_transform, throw)


func _on_reset_button_pressed() -> void:
	has_landed = false
	disc.reset(release_point.global_position)


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
		print("Flight Lab | distance: %.1f m (%.0f ft) | time: %.2f s | spin: %.0f rpm" % [
			distance_meters,
			distance_meters * METERS_TO_FEET,
			disc.flight_state.elapsed_time,
			disc.flight_state.spin_rate * 60.0 / TAU,
		])
