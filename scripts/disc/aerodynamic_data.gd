class_name AerodynamicData
extends Resource

@export var angles_degrees: Array[float] = []
@export var lift_coefficients: Array[float] = []
@export var drag_coefficients: Array[float] = []
# High-speed and low-speed pitching-moment curves share `angles_degrees`.
# Their interpolation represents the speed-dependent stability behavior of a
# mold; it is not an additive late-flight torque.
@export var moment_coefficients: Array[float] = []
@export var low_speed_moment_coefficients: Array[float] = []

@export_range(0.0, 100.0, 0.1, "suffix:m/s")
var low_speed_reference: float = 12.0

@export_range(0.0, 100.0, 0.1, "suffix:m/s")
var high_speed_reference: float = 22.0

# Human-readable provenance for authored coefficient curves.
@export_multiline var source_reference: String = ""


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var count := angles_degrees.size()
	if count < 2:
		errors.append("Aerodynamic data requires at least two angle samples.")
		return errors

	if lift_coefficients.size() != count \
		or drag_coefficients.size() != count \
		or moment_coefficients.size() != count \
		or low_speed_moment_coefficients.size() != count:
		errors.append("Aerodynamic coefficient arrays must match the angle sample count.")
		return errors

	for index in range(count):
		if not is_finite(angles_degrees[index]) \
			or not is_finite(lift_coefficients[index]) \
			or not is_finite(drag_coefficients[index]) \
			or not is_finite(moment_coefficients[index]) \
			or not is_finite(low_speed_moment_coefficients[index]):
			errors.append("Aerodynamic samples must be finite.")
			break
		if index > 0 and angles_degrees[index] <= angles_degrees[index - 1]:
			errors.append("Aerodynamic angle samples must be strictly increasing.")
			break
	if not is_finite(low_speed_reference) \
		or not is_finite(high_speed_reference) \
		or low_speed_reference < 0.0 \
		or high_speed_reference <= low_speed_reference:
		errors.append("Aerodynamic speed references must be finite and strictly increasing.")
	return errors


func is_valid() -> bool:
	return validate().is_empty()
	
func interpolate_coefficient(
	angle_of_attack: float,
	coefficients: Array[float]
) -> float:
	var angle_degrees = rad_to_deg(angle_of_attack)

	if angle_degrees <= angles_degrees[0]:
		return coefficients[0]

	if angle_degrees >= angles_degrees[-1]:
		return coefficients[-1]

	for i in range(angles_degrees.size() - 1):
		var lower_angle = angles_degrees[i]
		var upper_angle = angles_degrees[i + 1]

		if angle_degrees >= lower_angle and angle_degrees <= upper_angle:
			var interpolation_weight = inverse_lerp(
				lower_angle,
				upper_angle,
				angle_degrees
			)

			return lerp(
				coefficients[i],
				coefficients[i + 1],
				interpolation_weight
			)

	return 0.0

func get_lift_coefficient(angle_of_attack: float) -> float:
	return interpolate_coefficient(
		angle_of_attack,
		lift_coefficients
	)


func get_drag_coefficient(angle_of_attack: float) -> float:
	return interpolate_coefficient(
		angle_of_attack,
		drag_coefficients
	)


func get_moment_coefficient(
	angle_of_attack: float,
	air_speed: float,
) -> float:
	var high_speed_moment := interpolate_coefficient(
		angle_of_attack,
		moment_coefficients
	)
	var low_speed_moment := interpolate_coefficient(
		angle_of_attack,
		low_speed_moment_coefficients
	)
	var high_speed_progress: float = clampf(
		inverse_lerp(low_speed_reference, high_speed_reference, air_speed),
		0.0,
		1.0,
	)
	return lerp(low_speed_moment, high_speed_moment, high_speed_progress)
