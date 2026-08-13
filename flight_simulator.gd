class_name FlightSimulator
extends RefCounted


const GRAVITY: float = 9.81
const AIR_DENSITY: float = 1.225
const LIFT_COEFFICIENT: float = 0.15
const DRAG_COEFFICIENT: float = 0.08
const SPIN_DECAY_RATE: float = 0.15
const TURN_SPEED_THRESHOLD: float = 15.0
const TURN_RATE_SCALE: float = 0.8
const REFERENCE_SPIN_RATE: float = 60.0


func step(
	flight_state: FlightState,
	disc_data: DiscData,
	delta: float
) -> FlightState:
	var velocity = flight_state.velocity
	var spin_rate = flight_state.spin_rate
	var orientation = flight_state.orientation
	
	var updated_velocity = velocity
	var flight_direction = velocity.normalized()
	var radius = disc_data.diameter / 2.0
	var area = PI * radius * radius
	var speed = velocity.length()
	
	if speed <= 0.001:
		return flight_state
	
	var speed_above_threshold = max(
		speed - TURN_SPEED_THRESHOLD,
		0.0
	)
	var speed_factor = speed_above_threshold / TURN_SPEED_THRESHOLD
	var spin_resistance = max(
		spin_rate / REFERENCE_SPIN_RATE,
		0.1
	)
	var turn_rate = (
		disc_data.high_speed_turn
		* speed_factor
		* TURN_RATE_SCALE
		/ spin_resistance
	)
	var turn_rotation = Basis(
		flight_direction,
		turn_rate * delta
	)
	var updated_orientation = (
		turn_rotation * flight_state.orientation
	)
	
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

	var updated_spin_rate = max(
		spin_rate - SPIN_DECAY_RATE * delta,
		0.0
	)
	
	flight_state.velocity = updated_velocity
	flight_state.spin_rate = updated_spin_rate
	flight_state.orientation = updated_orientation
	
	return flight_state
