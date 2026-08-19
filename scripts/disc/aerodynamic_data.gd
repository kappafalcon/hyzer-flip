class_name AerodynamicData
extends Resource

@export var angles_degrees: Array[float] = []
@export var lift_coefficients: Array[float] = []
@export var drag_coefficients: Array[float] = []
@export var moment_coefficients: Array[float] = []
	
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


func get_moment_coefficient(angle_of_attack: float) -> float:
	return interpolate_coefficient(
		angle_of_attack,
		moment_coefficients
	)
