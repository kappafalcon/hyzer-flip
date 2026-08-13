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

const MIN_FLIGHT_SPEED: float = 0.001


func step(
	flight_state: FlightState,
	disc_data: DiscData,
	delta: float
) -> FlightState:
	var speed = flight_state.velocity.length()

	if speed <= MIN_FLIGHT_SPEED:
		return flight_state

	apply_gravity(flight_state, delta)
	apply_lift(flight_state, disc_data, delta)
	apply_drag(flight_state, disc_data, delta)
	apply_turn(flight_state, disc_data, delta)
	apply_spin_decay(flight_state, delta)

	return flight_state

	
func apply_gravity(
	flight_state: FlightState,
	delta: float
) -> void:
	flight_state.velocity.y -= GRAVITY * delta
	
	
func apply_lift(
	flight_state: FlightState,
	disc_data: DiscData,
	delta: float
) -> void:
	var speed = flight_state.velocity.length()
	var area = disc_data.get_area()

	var lift_force = (
		0.5
		* AIR_DENSITY
		* speed * speed
		* area
		* LIFT_COEFFICIENT
	)

	var lift_acceleration = lift_force / disc_data.mass
	var lift_direction = flight_state.orientation.y.normalized()

	flight_state.velocity += (
		lift_direction
		* lift_acceleration
		* delta
	)
	
	
func apply_drag(
	flight_state: FlightState,
	disc_data: DiscData,
	delta: float
) -> void:
	var speed = flight_state.velocity.length()

	if speed <= MIN_FLIGHT_SPEED:
		return

	var area = disc_data.get_area()

	var drag_force = (
		0.5
		* AIR_DENSITY
		* speed * speed
		* area
		* DRAG_COEFFICIENT
	)

	var drag_acceleration = drag_force / disc_data.mass
	var drag_direction = -flight_state.velocity.normalized()

	flight_state.velocity += (
		drag_direction
		* drag_acceleration
		* delta
	)
	
	
func apply_turn(
	flight_state: FlightState,
	disc_data: DiscData,
	delta: float
) -> void:
	var speed = flight_state.velocity.length()

	if speed <= MIN_FLIGHT_SPEED:
		return

	var speed_above_threshold = max(
		speed - TURN_SPEED_THRESHOLD,
		0.0
	)

	var speed_factor = (
		speed_above_threshold
		/ TURN_SPEED_THRESHOLD
	)

	var spin_resistance = max(
		flight_state.spin_rate / REFERENCE_SPIN_RATE,
		0.1
	)

	var turn_rate = (
		disc_data.high_speed_turn
		* speed_factor
		* TURN_RATE_SCALE
		/ spin_resistance
	)

	var flight_direction = flight_state.velocity.normalized()

	var turn_rotation = Basis(
		flight_direction,
		turn_rate * delta
	)

	flight_state.orientation = (
		turn_rotation
		* flight_state.orientation
	)
	
	
func apply_spin_decay(
	flight_state: FlightState,
	delta: float
) -> void:
	flight_state.spin_rate = max(
		flight_state.spin_rate
		- SPIN_DECAY_RATE * delta,
		0.0
	)
