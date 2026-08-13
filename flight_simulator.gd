class_name FlightSimulator
extends RefCounted


const GRAVITY: float = 9.81


func step_velocity(
	velocity: Vector3,
	delta: float
) -> Vector3:
	var new_velocity = velocity

	new_velocity.y -= GRAVITY * delta

	return new_velocity
