class_name FlightSimulator
extends RefCounted

# Aerodynamic force equation:
# F = 1/2 * rho * v^2 * A * C
const AERODYNAMIC_FORCE_FACTOR: float = 0.5

const GRAVITY: float = 9.81
const AIR_DENSITY: float = 1.225

const MIN_FLIGHT_SPEED: float = 0.001
const MIN_SPIN_RATE: float = 0.001
const MIN_SPIN_INERTIA: float = 0.000000001


func step(
	flight_state: FlightState,
	disc_data: DiscData,
	delta: float,
	environment: FlightEnvironment = null,
) -> FlightState:
	if delta <= 0.0 or flight_state.velocity.length() <= MIN_FLIGHT_SPEED:
		return flight_state.copy()
	var flight_environment := environment if environment != null else FlightEnvironment.new()

	# Evaluate every derivative from one state. The midpoint evaluation avoids
	# mixing an old coefficient lookup with a newly rolled orientation.
	var initial_derivative := calculate_derivative(flight_state, disc_data, flight_environment)
	var midpoint_state := advance_state(
		flight_state,
		initial_derivative,
		delta * 0.5,
	)
	var midpoint_derivative := calculate_derivative(midpoint_state, disc_data, flight_environment)
	var next_state := advance_state(flight_state, midpoint_derivative, delta)
	store_diagnostics(next_state, midpoint_derivative)
	return next_state


func calculate_derivative(
	flight_state: FlightState,
	disc_data: DiscData,
	environment: FlightEnvironment,
) -> Dictionary:
	var air_velocity := environment.get_air_velocity(flight_state.velocity)
	var angle_of_attack := calculate_angle_of_attack(flight_state, air_velocity)
	var lift_coefficient := disc_data.aerodynamics.get_lift_coefficient(
		angle_of_attack
	)
	var drag_coefficient := disc_data.aerodynamics.get_drag_coefficient(
		angle_of_attack
	)
	var moment_coefficient := disc_data.aerodynamics.get_moment_coefficient(
		angle_of_attack,
		air_velocity.length(),
	)
	var pitching_moment := calculate_pitching_moment(
		disc_data,
		moment_coefficient,
		air_velocity,
	)
	var torque_amplitude := calculate_torque_amplitude(disc_data, air_velocity)
	var roll_rate := calculate_roll_rate(
		flight_state,
		disc_data,
		pitching_moment
	)
	var gravity_force := calculate_gravity_force(disc_data)
	var lift_force := calculate_lift_force(
		flight_state, disc_data, lift_coefficient, air_velocity
	)
	var drag_force := calculate_drag_force(
		flight_state, disc_data, drag_coefficient, air_velocity
	)

	return {
		"velocity": flight_state.velocity,
		"acceleration": (gravity_force + lift_force + drag_force) / disc_data.mass,
		"spin_rate_change": calculate_spin_rate_change(
			flight_state,
			disc_data,
			torque_amplitude,
		),
		"roll_axis": calculate_roll_axis(flight_state, air_velocity),
		"roll_rate": roll_rate,
		"angle_of_attack": angle_of_attack,
		"lift_coefficient": lift_coefficient,
		"drag_coefficient": drag_coefficient,
		"moment_coefficient": moment_coefficient,
		"air_speed": air_velocity.length(),
	}


func advance_state(
	flight_state: FlightState,
	derivative: Dictionary,
	delta: float,
) -> FlightState:
	var next_state := flight_state.copy()
	next_state.position += derivative["velocity"] * delta
	next_state.velocity += derivative["acceleration"] * delta
	next_state.spin_rate = max(
		next_state.spin_rate + derivative["spin_rate_change"] * delta,
		0.0,
	)
	var roll_axis: Vector3 = derivative["roll_axis"]
	if roll_axis.length_squared() > 0.000001:
		# The roll rate already carries the signed zero-sideslip precession
		# direction. Applying a second sign inversion here reverses Eq. 11's
		# attitude update and creates an unphysical fade-then-turn loop.
		var roll_rotation := Basis(
			roll_axis,
			derivative["roll_rate"] * delta,
		)
		next_state.orientation = (
			roll_rotation * next_state.orientation
		).orthonormalized()
	next_state.elapsed_time += delta
	next_state.tick += 1
	return next_state


func store_diagnostics(flight_state: FlightState, derivative: Dictionary) -> void:
	flight_state.angle_of_attack = derivative["angle_of_attack"]
	flight_state.lift_coefficient = derivative["lift_coefficient"]
	flight_state.drag_coefficient = derivative["drag_coefficient"]
	flight_state.moment_coefficient = derivative["moment_coefficient"]
	flight_state.roll_rate = derivative["roll_rate"]
	flight_state.air_speed = derivative["air_speed"]


func calculate_gravity_force(disc_data: DiscData) -> Vector3:
	return Vector3.DOWN * disc_data.mass * GRAVITY


func calculate_lift_force(
	flight_state: FlightState,
	disc_data: DiscData,
	lift_coefficient: float,
	air_velocity: Vector3,
) -> Vector3:
	var speed = air_velocity.length()
	var area = disc_data.get_area()
	var lift_force = (
		AERODYNAMIC_FORCE_FACTOR
		* AIR_DENSITY
		* speed * speed
		* area
		* lift_coefficient
	)

	var velocity_direction = air_velocity.normalized()
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
	drag_coefficient: float,
	air_velocity: Vector3,
) -> Vector3:
	var speed = air_velocity.length()

	if speed <= MIN_FLIGHT_SPEED:
		return Vector3.ZERO

	var area = disc_data.get_area()
	
	var drag_force = (
		AERODYNAMIC_FORCE_FACTOR
		* AIR_DENSITY
		* speed * speed
		* area
		* drag_coefficient
	)

	var drag_direction = -air_velocity.normalized()

	return drag_direction * drag_force
	

func calculate_angle_of_attack(
	flight_state: FlightState,
	air_velocity: Vector3,
) -> float:
	var disc_forward = -flight_state.orientation.z.normalized()
	var disc_normal = flight_state.orientation.y.normalized()

	return -atan2(
		air_velocity.dot(disc_normal),
		air_velocity.dot(disc_forward),
	)


func calculate_pitching_moment(
	disc_data: DiscData,
	moment_coefficient: float,
	air_velocity: Vector3,
) -> float:
	return calculate_torque_amplitude(disc_data, air_velocity) * moment_coefficient


func calculate_torque_amplitude(
	disc_data: DiscData,
	air_velocity: Vector3,
) -> float:
	var speed = air_velocity.length()
	var area = disc_data.get_area()


	var dynamic_pressure = (
		AERODYNAMIC_FORCE_FACTOR
		* AIR_DENSITY
		* speed
		* speed
	)

	return dynamic_pressure * disc_data.diameter * area


func calculate_spin_rate_change(
	flight_state: FlightState,
	disc_data: DiscData,
	torque_amplitude: float,
) -> float:
	var legacy_decay := -disc_data.spin_decay_rate
	if disc_data.spin_moment_of_inertia <= MIN_SPIN_INERTIA:
		return legacy_decay
	var aerodynamic_decay := (
		disc_data.aerodynamic_spin_damping
		* torque_amplitude
		* flight_state.spin_rate
		/ disc_data.spin_moment_of_inertia
	)
	return legacy_decay + aerodynamic_decay
	

func calculate_roll_rate(
	flight_state: FlightState,
	disc_data: DiscData,
	pitching_moment: float
) -> float:
	if abs(flight_state.spin_rate) <= MIN_SPIN_RATE:
		return 0.0

	if disc_data.spin_moment_of_inertia <= MIN_SPIN_INERTIA:
		return 0.0

	# Aerodynamic torque changes the disc attitude through its angular momentum
	# about the spin axis. This follows the precession relationship used by the
	# MIT-licensed FrisPy reference model; the old radial-minus-spin denominator
	# over-rotated the attitude for our disc inertia values.
	return pitching_moment / (
		flight_state.spin_rate
		* disc_data.spin_moment_of_inertia
	)
	

func calculate_roll_axis(
	flight_state: FlightState,
	air_velocity: Vector3,
) -> Vector3:
	if air_velocity.length_squared() <= MIN_FLIGHT_SPEED * MIN_FLIGHT_SPEED:
		return Vector3.ZERO
	var velocity_direction = air_velocity.normalized()
	var disc_normal = flight_state.orientation.y.normalized()

	var velocity_into_normal = (
		velocity_direction.dot(disc_normal)
		* disc_normal
	)

	var roll_axis = velocity_direction - velocity_into_normal

	if roll_axis.length_squared() <= 0.000001:
		return Vector3.ZERO

	return roll_axis.normalized()
