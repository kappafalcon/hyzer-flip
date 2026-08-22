class_name ArcadeThrowCommand
extends RefCounted

## Immutable player-facing input captured at arcade throw release.
##
## Release bank is mold-relative: positive values point toward the disc's
## natural finish side. Spin direction maps that local convention into world
## space so the same authored profile mirrors for the opposite throw side.

enum SpinDirection {
	NATURAL_FINISH_LEFT = -1,
	NATURAL_FINISH_RIGHT = 1,
}

var origin: Vector3
var horizontal_forward: Vector3
var charge: float
var release_bank_degrees: float
var launch_pitch_degrees: float
var spin_direction: SpinDirection


func _init(
	initial_origin: Vector3,
	initial_horizontal_forward: Vector3,
	initial_charge: float,
	initial_release_bank_degrees: float,
	initial_launch_pitch_degrees: float,
	initial_spin_direction: SpinDirection,
) -> void:
	origin = initial_origin
	horizontal_forward = Vector3(
		initial_horizontal_forward.x,
		0.0,
		initial_horizontal_forward.z,
	)
	if horizontal_forward.length_squared() > 0.0:
		horizontal_forward = horizontal_forward.normalized()
	charge = initial_charge
	release_bank_degrees = initial_release_bank_degrees
	launch_pitch_degrees = initial_launch_pitch_degrees
	spin_direction = initial_spin_direction


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _is_finite_vector(origin):
		errors.append("Arcade throw origin must be finite.")
	if not _is_finite_vector(horizontal_forward) \
		or horizontal_forward.length_squared() <= 0.000001:
		errors.append("Arcade throw requires a non-zero horizontal forward direction.")
	if not is_finite(charge) or charge < 0.0 or charge > 1.0:
		errors.append("Arcade throw charge must be finite and within 0.0 through 1.0.")
	if not is_finite(release_bank_degrees):
		errors.append("Arcade throw release bank must be finite.")
	if not is_finite(launch_pitch_degrees):
		errors.append("Arcade throw launch pitch must be finite.")
	if spin_direction != SpinDirection.NATURAL_FINISH_LEFT \
		and spin_direction != SpinDirection.NATURAL_FINISH_RIGHT:
		errors.append("Arcade throw spin direction must map to a natural finish side.")
	return errors


func is_valid() -> bool:
	return validate().is_empty()


func get_spin_sign() -> float:
	return float(spin_direction)


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)
