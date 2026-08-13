class_name FlightSimulator
extends RefCounted


const GRAVITY: float = 9.81
const AIR_DENSITY: float = 1.225
const LIFT_COEFFICIENT: float = 0.15
const DRAG_COEFFICIENT: float = 0.08

func step(
	flight_state: FlightState,
	disc_data: DiscData,
	delta: float
) -> FlightState:
	var velocity = flight_state.velocity
	var orientation = flight_state.orientation
	
	var updated_velocity = velocity
	var radius = disc_data.diameter / 2.0
	var area = PI * radius * radius
	var speed = velocity.length()
	
	if speed <= 0.001:
		return flight_state
	
	# This determines hyzer/anhyzer flight characteristics
	var disc_plane = orientation.y.normalized()
	
	var lift_force = (
		0.5
		* AIR_DENSITY
		* speed * speed
		* area
		* LIFT_COEFFICIENT
	)
	var lift_acceleration = lift_force / disc_data.mass
	var lift_direction = disc_plane

	var drag_force = (
		0.5
		* AIR_DENSITY
		* speed * speed
		* area
		* DRAG_COEFFICIENT
	)
	var drag_acceleration = drag_force / disc_data.mass
	var drag_direction = -velocity.normalized()

	# Apply gravity
	updated_velocity.y -= GRAVITY * delta
	
	# Apply lift in the direction perpendicular to the disc
	updated_velocity += lift_direction * lift_acceleration * delta
	
	# Apply drag opposite the direction of travel
	updated_velocity += drag_direction * drag_acceleration * delta

	flight_state.velocity = updated_velocity
	
	return flight_state
