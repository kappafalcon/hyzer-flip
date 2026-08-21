extends Node3D

signal flight_segment_advanced(
	previous_position: Vector3,
	next_position: Vector3,
)

@export var disc_data: DiscData

var flight_state: FlightState
var is_flying: bool = false
var simulated_flight = FlightSimulator.new()

var debug_flight_time: float = 0.0
# This function constantly updates the position of the disc after launch
func _physics_process(delta):
	if not is_flying:
		return

	var previous_global_position := global_position
	flight_state = simulated_flight.step(flight_state, disc_data, delta)
	var next_global_position: Vector3 = (
		previous_global_position
		+ flight_state.velocity * delta
	)

	global_transform.basis = flight_state.orientation
	global_position = next_global_position
	flight_segment_advanced.emit(
		previous_global_position,
		next_global_position,
	)


# This function uses the arguments passed to update the flight characteristics of the now flying disc
func launch(
	initial_transform: Transform3D,
	throw: ThrowParameters
) -> void:
	global_transform = initial_transform

	# Set release orientation.
	rotation_degrees = Vector3(
		throw.launch_angle + throw.nose_angle,
		0.0,
		throw.release_angle
	)

	var launch_angle_rad := deg_to_rad(throw.launch_angle)

	var local_velocity := Vector3(
		0.0,
		sin(launch_angle_rad) * throw.speed,
		-cos(launch_angle_rad) * throw.speed,
	)

	var initial_velocity : Vector3 = initial_transform.basis * local_velocity

	flight_state = FlightState.new(
		initial_velocity,
		throw.spin_rate,
		global_transform.basis
	)

	is_flying = true


func stop_at(landing_position: Vector3) -> void:
	is_flying = false
	global_position = landing_position


func reset(reset_position: Vector3) -> void:
	is_flying = false
	flight_state = null

	global_position = reset_position
	rotation = Vector3.ZERO
