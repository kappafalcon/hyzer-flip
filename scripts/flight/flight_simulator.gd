class_name FlightSimulator
extends RefCounted

# Aerodynamic force equation:
# F = 1/2 * rho * v^2 * A * C
const AERODYNAMIC_FORCE_FACTOR: float = 0.5

const GRAVITY: float = 9.81
const AIR_DENSITY: float = 1.225

const SPIN_DECAY_RATE: float = 0.15

const TURN_SPEED_THRESHOLD: float = 15.0
const TURN_RATE_SCALE: float = 0.8
const REFERENCE_SPIN_RATE: float = 60.0

const MIN_FLIGHT_SPEED: float = 0.001
const MIN_SPIN_RATE: float = 0.001
const MIN_INERTIA_DIFFERENCE: float = 0.000000001

func step(flight_state: FlightState, disc_data: DiscData, delta: float) -> FlightState:
	var speed = flight_state.velocity.length()

	if speed <= MIN_FLIGHT_SPEED:
		return flight_state
		
	var angle_of_attack = calculate_angle_of_attack(flight_state)
	
	var pitching_moment = calculate_pitching_moment(
		flight_state,
		disc_data,
		angle_of_attack
	)
	var roll_rate = calculate_roll_rate(
		flight_state,
		disc_data,
		pitching_moment
	)
	var roll_axis = calculate_roll_axis(flight_state)
	apply_roll(
		flight_state,
		roll_axis,
		roll_rate,
		delta
	)
	var gravity_force = calculate_gravity_force(disc_data)
	var lift_force = calculate_lift_force(
		flight_state,
		disc_data,
		angle_of_attack
	)
	var drag_force = calculate_drag_force(
		flight_state,
		disc_data,
		angle_of_attack
	)
	
	# The total force acting on the disc from gravity and lift
	var net_force = (
		gravity_force
		+ lift_force
		+ drag_force
	)
	var acceleration = net_force / disc_data.mass
	
	flight_state.velocity += acceleration * delta

	return flight_state


func calculate_gravity_force(disc_data: DiscData) -> Vector3:
	return Vector3.DOWN * disc_data.mass * GRAVITY


func calculate_lift_force(
	flight_state: FlightState,
	disc_data: DiscData,
	angle_of_attack: float
) -> Vector3:
	var speed = flight_state.velocity.length()
	var area = disc_data.get_area()
	var lift_coefficient = (
		disc_data.aerodynamics.get_lift_coefficient(angle_of_attack)
	)
	var lift_force = (
		AERODYNAMIC_FORCE_FACTOR
		* AIR_DENSITY
		* speed * speed
		* area
		* lift_coefficient
	)

	var velocity_direction = flight_state.velocity.normalized()
	var disc_normal = flight_state.orientation.y.normalized()

	var normal_along_velocity = (
		disc_normal.dot(velocity_direction)
		* velocity_direction
	)

	var lift_direction = disc_normal - normal_along_velocity

	if lift_direction.length_squared() <= 0.000001:
		return Vector3.ZERO

	lift_direction = lift_direction.normalized()

	return lift_direction * lift_force	
	
	
	
func calculate_drag_force(
	flight_state: FlightState,
	disc_data: DiscData,
	angle_of_attack: float
) -> Vector3:
	var speed = flight_state.velocity.length()

	if speed <= MIN_FLIGHT_SPEED:
		return Vector3.ZERO

	var area = disc_data.get_area()
	
	var drag_coefficient = (
		disc_data.aerodynamics.get_drag_coefficient(angle_of_attack)
	)
	var drag_force = (
		AERODYNAMIC_FORCE_FACTOR
		* AIR_DENSITY
		* speed * speed
		* area
		* drag_coefficient
	)

	var drag_direction = -flight_state.velocity.normalized()

	return drag_direction * drag_force
	

func apply_turn(flight_state: FlightState, disc_data: DiscData, delta: float) -> void:
	var speed = flight_state.velocity.length()

	if speed <= MIN_FLIGHT_SPEED:
		return

	var speed_above_threshold = max(speed - TURN_SPEED_THRESHOLD, 0.0)

	var speed_factor = speed_above_threshold / TURN_SPEED_THRESHOLD

	var spin_resistance = max(flight_state.spin_rate / REFERENCE_SPIN_RATE, 0.1)

	var turn_rate = disc_data.high_speed_turn * speed_factor * TURN_RATE_SCALE / spin_resistance

	var flight_direction = flight_state.velocity.normalized()

	var turn_rotation = Basis(flight_direction, turn_rate * delta)

	flight_state.orientation = (turn_rotation * flight_state.orientation)


func apply_spin_decay(flight_state: FlightState, delta: float) -> void:
	flight_state.spin_rate = max(flight_state.spin_rate - SPIN_DECAY_RATE * delta, 0.0)


func calculate_angle_of_attack(flight_state: FlightState) -> float:
	var flight_direction = flight_state.velocity.normalized()
	var disc_normal = flight_state.orientation.y.normalized()

	var vertical_component = flight_direction.dot(disc_normal)

	return -asin(clamp(vertical_component, -1.0, 1.0))


func calculate_pitching_moment(
	flight_state: FlightState,
	disc_data: DiscData,
	angle_of_attack: float
) -> float:
	var speed = flight_state.velocity.length()
	var area = disc_data.get_area()

	var moment_coefficient = (
		disc_data.aerodynamics.get_moment_coefficient(angle_of_attack)
	)

	var dynamic_pressure = (
		AERODYNAMIC_FORCE_FACTOR
		* AIR_DENSITY
		* speed
		* speed
	)

	return (
		dynamic_pressure
		* moment_coefficient
		* disc_data.diameter
		* area
	)
	

func calculate_roll_rate(
	flight_state: FlightState,
	disc_data: DiscData,
	pitching_moment: float
) -> float:
	var inertia_difference = (
		disc_data.radial_moment_of_inertia
		- disc_data.spin_moment_of_inertia
	)

	if abs(flight_state.spin_rate) <= MIN_SPIN_RATE:
		return 0.0

	if abs(inertia_difference) <= MIN_INERTIA_DIFFERENCE:
		return 0.0

	return -pitching_moment / (
		flight_state.spin_rate
		* inertia_difference
	)
	

func calculate_roll_axis(flight_state: FlightState) -> Vector3:
	var velocity_direction = flight_state.velocity.normalized()
	var disc_normal = flight_state.orientation.y.normalized()

	var velocity_into_normal = (
		velocity_direction.dot(disc_normal)
		* disc_normal
	)

	var roll_axis = velocity_direction - velocity_into_normal

	if roll_axis.length_squared() <= 0.000001:
		return Vector3.ZERO

	return roll_axis.normalized()


func apply_roll(
	flight_state: FlightState,
	roll_axis: Vector3,
	roll_rate: float,
	delta: float
) -> void:
	if roll_axis == Vector3.ZERO:
		return

	var roll_angle = roll_rate * delta
	var roll_rotation = Basis(roll_axis, roll_angle)

	flight_state.orientation = (
		roll_rotation
		* flight_state.orientation
	).orthonormalized()
