extends Node3D

#const GRAVITY: float = 9.81

var velocity: Vector3 = Vector3.ZERO
var is_flying: bool = false
var simulator = FlightSimulator.new()

func _physics_process(delta):
	if not is_flying:
		return
		
	velocity = simulator.step_velocity(velocity, delta)
	position += velocity * delta
	
func launch(
	initial_position: Vector3,
	initial_velocity: Vector3,
	release_angle: float
):
	global_position = initial_position
	velocity = initial_velocity
	rotation_degrees.z = release_angle
	is_flying = true
