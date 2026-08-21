extends Node3D

signal flight_segment_advanced(
	previous_position: Vector3,
	next_position: Vector3,
)

@export var disc_data: DiscData

var flight_state: FlightState
var is_flying: bool = false
var simulated_flight = FlightSimulator.new()
var flight_environment := FlightEnvironment.new()

const SIMULATION_TIMESTEP := 1.0 / 120.0

var simulation_time_accumulator := 0.0


func _physics_process(delta: float) -> void:
	if not is_flying:
		return

	simulation_time_accumulator += delta
	while simulation_time_accumulator >= SIMULATION_TIMESTEP and is_flying:
		var previous_position := flight_state.position
		flight_state = simulated_flight.step(
			flight_state,
			disc_data,
			SIMULATION_TIMESTEP,
			flight_environment,
		)
		simulation_time_accumulator -= SIMULATION_TIMESTEP
		_publish_flight_state()
		flight_segment_advanced.emit(previous_position, flight_state.position)


func _publish_flight_state() -> void:
	global_transform = Transform3D(flight_state.orientation, flight_state.position)


# This function uses the arguments passed to update the flight characteristics of the now flying disc
func launch(
	initial_transform: Transform3D,
	throw: ThrowParameters
) -> void:
	if disc_data == null:
		push_error("Disc launch requires DiscData.")
		return
	var validation_errors := disc_data.validate()
	if not validation_errors.is_empty():
		push_error("Disc launch rejected invalid data: %s" % ", ".join(validation_errors))
		return

	flight_state = FlightLaunch.create_state(
		initial_transform.origin,
		initial_transform.basis,
		throw,
	)
	simulation_time_accumulator = 0.0
	_publish_flight_state()
	is_flying = true


func stop_at(landing_position: Vector3) -> void:
	is_flying = false
	if flight_state != null:
		flight_state.position = landing_position
	_publish_flight_state()


func reset(reset_position: Vector3) -> void:
	is_flying = false
	flight_state = null
	simulation_time_accumulator = 0.0

	global_position = reset_position
	rotation = Vector3.ZERO
