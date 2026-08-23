class_name ArcadeThrowCommand
extends RefCounted

## Immutable player-facing input captured at arcade throw release.
##
## Release bank is mold-relative: positive values point toward the disc's
## natural finish side. Fade direction maps that local convention into world
## space so the same authored profile mirrors for the opposite throw side.


const MIN_HORIZONTAL_FORWARD_LENGTH_SQUARED: float = 0.000001


# The simulator needs a multiplier to convert the player's local release bank into a world-space target bank.
# The fade direction is used to determine which side of the disc's natural finish the throw is on, allowing for proper mirroring of the flight profile.
enum FadeDirection {
	UNSPECIFIED = 0,
	NATURAL_FINISH_LEFT = 1,
	NATURAL_FINISH_RIGHT = -1,
}

var _origin: Vector3
var _horizontal_forward: Vector3
var _charge: float
var _release_bank_degrees: float
var _launch_pitch_degrees: float
var _fade_direction: FadeDirection = FadeDirection.UNSPECIFIED

var origin: Vector3:
	get:
		return _origin

var horizontal_forward: Vector3:
	get:
		return _horizontal_forward

var charge: float:
	get:
		return _charge

var release_bank_degrees: float:
	get:
		return _release_bank_degrees

var launch_pitch_degrees: float:
	get:
		return _launch_pitch_degrees

var fade_direction: FadeDirection:
	get:
		return _fade_direction


func _init(
	initial_origin: Vector3,
	initial_horizontal_forward: Vector3,
	initial_charge: float,
	initial_release_bank_degrees: float,
	initial_launch_pitch_degrees: float,
	initial_fade_direction: FadeDirection,
) -> void:
	_origin = initial_origin
	_horizontal_forward = _normalize_horizontal_forward(initial_horizontal_forward)
	_charge = initial_charge
	_release_bank_degrees = initial_release_bank_degrees
	_launch_pitch_degrees = initial_launch_pitch_degrees
	_fade_direction = initial_fade_direction


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not _is_finite_vector(origin):
		errors.append("Arcade throw origin must be finite.")
	if not _is_finite_vector(horizontal_forward) \
		or horizontal_forward.length_squared() <= MIN_HORIZONTAL_FORWARD_LENGTH_SQUARED:
		errors.append("Arcade throw requires a non-zero horizontal forward direction.")
	if not is_finite(charge) or charge < 0.0 or charge > 1.0:
		errors.append("Arcade throw charge must be finite and within 0.0 through 1.0.")
	if not is_finite(release_bank_degrees):
		errors.append("Arcade throw release bank must be finite.")
	if not is_finite(launch_pitch_degrees):
		errors.append("Arcade throw launch pitch must be finite.")
	if fade_direction != FadeDirection.NATURAL_FINISH_LEFT \
		and fade_direction != FadeDirection.NATURAL_FINISH_RIGHT:
		errors.append("Arcade throw fade direction must map to a natural finish side.")
	return errors


func is_valid() -> bool:
	return validate().is_empty()


func get_fade_sign() -> float:
	return float(fade_direction)


func _is_finite_vector(value: Vector3) -> bool:
	return is_finite(value.x) and is_finite(value.y) and is_finite(value.z)


func _normalize_horizontal_forward(value: Vector3) -> Vector3:
	var initial_horizontal_forward := Vector3(value.x, 0.0, value.z)
	# Preserve invalid input so validate() can reject it instead of turning it
	# into a valid-looking unit direction.
	if not _is_finite_vector(initial_horizontal_forward) \
		or initial_horizontal_forward.length_squared() <= MIN_HORIZONTAL_FORWARD_LENGTH_SQUARED:
		return initial_horizontal_forward
	return initial_horizontal_forward.normalized()
