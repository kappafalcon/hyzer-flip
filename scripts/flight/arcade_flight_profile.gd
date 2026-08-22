class_name ArcadeFlightProfile
extends Resource

## Immutable authored data for one arcade disc-flight identity.
##
## All curves use a unit input domain. Charge and flight phase are sampled from
## 0.0 through 1.0; launch pitch maps from downward (0.0), through flat (0.5),
## to upward (1.0). Curve outputs are documented by the exported property name.

enum Stability {
	OVERSTABLE,
	NEUTRAL,
	UNDERSTABLE,
}

const CURVE_SAMPLE_OFFSETS := [0.0, 0.25, 0.5, 0.75, 1.0]

@export_category("Identity")
@export var profile_id: StringName
@export var stability: Stability = Stability.NEUTRAL

@export_category("Flight Limits")
@export_range(0.0, 100.0, 0.1, "suffix:m/s")
var base_forward_speed_mps: float = 0.0

@export_range(0.0, 20.0, 0.01, "suffix:s")
var phase_duration_seconds: float = 0.0

@export_range(0.0, 200.0, 0.1, "suffix:m")
var maximum_travel_distance_meters: float = 0.0

@export_range(0.0, 90.0, 0.1, "suffix:degrees")
var maximum_bank_degrees: float = 0.0

@export_range(0.0, 720.0, 0.1, "suffix:degrees/s")
var bank_response_degrees_per_second: float = 0.0

@export_range(0.0, 720.0, 0.1, "suffix:degrees/s")
var maximum_heading_turn_degrees_per_second: float = 0.0

@export_range(0.0, 90.0, 0.1, "suffix:degrees")
var maximum_launch_pitch_degrees: float = 0.0

@export_range(0.0, 1.1, 0.01)
var roller_entry_phase: float = 1.1

## Roller entry is enabled only when its phase is at most 1.0. The bank
## threshold is evaluated in world-space bank magnitude so it mirrors with spin.
@export_range(0.0, 90.0, 0.1, "suffix:degrees")
var roller_entry_bank_degrees: float = 90.0

@export_category("Charge Curves")
@export var speed_multiplier_by_charge: Curve
@export var glide_multiplier_by_charge: Curve
@export var phase_rate_multiplier_by_charge: Curve

@export_category("Flight Phase Curves")
@export var speed_multiplier_by_phase: Curve
@export var bank_bias_degrees_by_phase: Curve
@export var vertical_acceleration_mps2_by_phase: Curve

@export_category("Launch Pitch Curve")
@export var stability_bank_degrees_by_launch_pitch: Curve


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if profile_id.is_empty():
		errors.append("Arcade flight profile requires a profile ID.")
	if not _is_positive_finite(base_forward_speed_mps):
		errors.append("Base forward speed must be finite and positive.")
	if not _is_positive_finite(phase_duration_seconds):
		errors.append("Phase duration must be finite and positive.")
	if not _is_positive_finite(maximum_travel_distance_meters):
		errors.append("Maximum travel distance must be finite and positive.")
	if not _is_positive_finite(maximum_bank_degrees):
		errors.append("Maximum bank must be finite and positive.")
	if not _is_positive_finite(bank_response_degrees_per_second):
		errors.append("Bank response must be finite and positive.")
	if not _is_positive_finite(maximum_heading_turn_degrees_per_second):
		errors.append("Maximum heading turn rate must be finite and positive.")
	if not _is_positive_finite(maximum_launch_pitch_degrees):
		errors.append("Maximum launch pitch must be finite and positive.")
	if not is_finite(roller_entry_phase) \
		or roller_entry_phase < 0.0 \
		or roller_entry_phase > 1.1:
		errors.append("Roller entry phase must be finite and within 0.0 through 1.1.")
	if not is_finite(roller_entry_bank_degrees) or roller_entry_bank_degrees <= 0.0:
		errors.append("Roller entry bank must be finite and positive.")
	elif roller_entry_phase <= 1.0 and roller_entry_bank_degrees > maximum_bank_degrees:
		errors.append("Enabled roller entry bank must not exceed maximum bank.")

	_validate_positive_curve(speed_multiplier_by_charge, "Charge speed", errors)
	_validate_non_negative_curve(glide_multiplier_by_charge, "Charge glide", errors)
	_validate_positive_curve(phase_rate_multiplier_by_charge, "Charge phase rate", errors)
	_validate_non_negative_curve(speed_multiplier_by_phase, "Phase speed", errors)
	_validate_finite_curve(bank_bias_degrees_by_phase, "Phase bank bias", errors)
	_validate_finite_curve(
		vertical_acceleration_mps2_by_phase,
		"Phase vertical acceleration",
		errors,
	)
	_validate_finite_curve(
		stability_bank_degrees_by_launch_pitch,
		"Launch-pitch stability",
		errors,
	)
	return errors


func is_valid() -> bool:
	return validate().is_empty()


func sample_charge_speed_multiplier(charge: float) -> float:
	return _sample_unit_curve(speed_multiplier_by_charge, charge)


func sample_charge_glide_multiplier(charge: float) -> float:
	return _sample_unit_curve(glide_multiplier_by_charge, charge)


func sample_charge_phase_rate_multiplier(charge: float) -> float:
	return _sample_unit_curve(phase_rate_multiplier_by_charge, charge)


func sample_phase_speed_multiplier(flight_phase: float) -> float:
	return _sample_unit_curve(speed_multiplier_by_phase, flight_phase)


func sample_phase_bank_bias_degrees(flight_phase: float) -> float:
	return _sample_unit_curve(bank_bias_degrees_by_phase, flight_phase)


func sample_phase_vertical_acceleration(flight_phase: float) -> float:
	return _sample_unit_curve(vertical_acceleration_mps2_by_phase, flight_phase)


func sample_launch_pitch_stability_bias(launch_pitch_degrees: float) -> float:
	var normalized_pitch := inverse_lerp(
		-maximum_launch_pitch_degrees,
		maximum_launch_pitch_degrees,
		clampf(
			launch_pitch_degrees,
			-maximum_launch_pitch_degrees,
			maximum_launch_pitch_degrees,
		),
	)
	return _sample_unit_curve(stability_bank_degrees_by_launch_pitch, normalized_pitch)


func _sample_unit_curve(curve: Curve, offset: float) -> float:
	assert(curve != null, "Arcade flight profile curve is missing.")
	return curve.sample(clampf(offset, 0.0, 1.0))


func _validate_positive_curve(
	curve: Curve,
	label: String,
	errors: PackedStringArray,
) -> void:
	if not _validate_unit_curve(curve, label, errors):
		return
	for offset in CURVE_SAMPLE_OFFSETS:
		var value := curve.sample(offset)
		if not _is_positive_finite(value):
			errors.append("%s curve samples must be finite and positive." % label)
			return


func _validate_non_negative_curve(
	curve: Curve,
	label: String,
	errors: PackedStringArray,
) -> void:
	if not _validate_unit_curve(curve, label, errors):
		return
	for offset in CURVE_SAMPLE_OFFSETS:
		var value := curve.sample(offset)
		if not is_finite(value) or value < 0.0:
			errors.append("%s curve samples must be finite and non-negative." % label)
			return


func _validate_finite_curve(
	curve: Curve,
	label: String,
	errors: PackedStringArray,
) -> void:
	if not _validate_unit_curve(curve, label, errors):
		return
	for offset in CURVE_SAMPLE_OFFSETS:
		if not is_finite(curve.sample(offset)):
			errors.append("%s curve samples must be finite." % label)
			return


func _validate_unit_curve(
	curve: Curve,
	label: String,
	errors: PackedStringArray,
) -> bool:
	if curve == null:
		errors.append("%s curve is required." % label)
		return false
	if curve.point_count < 2:
		errors.append("%s curve requires at least two points." % label)
		return false
	var first_offset := curve.get_point_position(0).x
	var last_offset := curve.get_point_position(curve.point_count - 1).x
	if first_offset > 0.0 or last_offset < 1.0:
		errors.append("%s curve must cover the unit domain from 0.0 through 1.0." % label)
		return false
	return true


func _is_positive_finite(value: float) -> bool:
	return is_finite(value) and value > 0.0
