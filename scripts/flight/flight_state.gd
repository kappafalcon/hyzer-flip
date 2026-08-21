class_name FlightState
extends RefCounted

var position: Vector3
var velocity: Vector3
var spin_rate: float
var orientation: Basis
var elapsed_time: float
var tick: int

# These values describe the most recently evaluated simulation state. They are
# for lab diagnostics only and do not affect the next solver step.
var angle_of_attack: float
var lift_coefficient: float
var drag_coefficient: float
var moment_coefficient: float
var roll_rate: float
var air_speed: float


func _init(
	initial_position: Vector3,
	initial_velocity: Vector3,
	initial_spin_rate: float,
	initial_orientation: Basis,
	initial_elapsed_time: float = 0.0,
	initial_tick: int = 0,
):
	position = initial_position
	velocity = initial_velocity
	spin_rate = initial_spin_rate
	orientation = initial_orientation.orthonormalized()
	elapsed_time = initial_elapsed_time
	tick = initial_tick


func copy() -> FlightState:
	var copied_state := FlightState.new(
		position,
		velocity,
		spin_rate,
		orientation,
		elapsed_time,
		tick,
	)
	copied_state.angle_of_attack = angle_of_attack
	copied_state.lift_coefficient = lift_coefficient
	copied_state.drag_coefficient = drag_coefficient
	copied_state.moment_coefficient = moment_coefficient
	copied_state.roll_rate = roll_rate
	copied_state.air_speed = air_speed
	return copied_state
