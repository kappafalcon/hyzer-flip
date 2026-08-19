extends Node3D

@export var disc_data: DiscData

var flight_state: FlightState
var is_flying: bool = false
var simulated_flight = FlightSimulator.new()


# This function constantly updates the position of the disc after launch
func _physics_process(delta):	
	if not is_flying:
		return

	flight_state = simulated_flight.step(flight_state, disc_data, delta)

	global_transform.basis = flight_state.orientation
	position += flight_state.velocity * delta


# This function uses the arguments passed to update the flight characteristics of the now flying disc
func launch(
	initial_position: Vector3,
	throw: ThrowParameters
) -> void:
	global_position = initial_position

	# Set release orientation.
	rotation_degrees = Vector3(
		-throw.nose_angle,
		0.0,
		throw.release_angle
	)

	var initial_velocity = Vector3(
		0.0,
		0.0,
		-throw.speed
	)

	flight_state = FlightState.new(
		initial_velocity,
		throw.spin_rate,
		global_transform.basis
	)

	is_flying = true

func reset(reset_position: Vector3) -> void:
	is_flying = false
	flight_state = null

	global_position = reset_position
	rotation = Vector3.ZERO
