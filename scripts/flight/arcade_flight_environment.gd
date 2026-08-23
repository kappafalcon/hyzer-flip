class_name ArcadeFlightEnvironment
extends RefCounted

## Explicit world inputs for the arcade airborne simulator.
##
## Collision, wind, and terrain queries intentionally do not belong here. A
## future deterministic collision adapter consumes simulator segments instead.

var gravity_mps2: float


func _init(initial_gravity_mps2: float = 9.81) -> void:
	gravity_mps2 = initial_gravity_mps2


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not is_finite(gravity_mps2) or gravity_mps2 < 0.0:
		errors.append("Arcade gravity must be finite and non-negative.")
	return errors


func is_valid() -> bool:
	return validate().is_empty()
