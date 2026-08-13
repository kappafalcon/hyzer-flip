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
	print(
	"Speed: ",
	flight_state.velocity.length(),
	" m/s | Spin: ",
	flight_state.spin_rate,
    " rad/s"
)
	global_transform.basis = flight_state.orientation
	position += flight_state.velocity * delta
	

# This function uses the arguments passed to update the flight characteristics of the now flying disc
func launch(
	initial_position: Vector3,
	initial_velocity: Vector3,
	initial_spin_rate: float,
	release_angle: float
):
	global_position = initial_position
	rotation_degrees.z = release_angle
	flight_state = FlightState.new(initial_velocity, initial_spin_rate, global_transform.basis)
	is_flying = true
