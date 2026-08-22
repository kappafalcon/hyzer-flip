class_name ArcadeFlightState
extends RefCounted

## Complete replayable state for the pure arcade airborne simulator.

enum Lifecycle {
	FLYING,
	ROLLER_ENTRY,
	EXHAUSTED,
}

var position: Vector3
var velocity: Vector3
var horizontal_heading: Vector3
var orientation: Basis
var initial_forward_speed_mps: float
var charge: float
var release_bank_degrees: float
var launch_pitch_degrees: float
var spin_sign: float
var flight_phase: float
var bank_degrees: float
var target_bank_degrees: float
var launch_pitch_stability_bias_degrees: float
var travel_distance_meters: float
var elapsed_time: float
var tick: int
var lifecycle: Lifecycle


func _init(
	initial_position: Vector3,
	initial_velocity: Vector3,
	initial_horizontal_heading: Vector3,
	initial_orientation: Basis,
	initial_forward_speed_mps: float,
	initial_charge: float,
	initial_release_bank_degrees: float,
	initial_launch_pitch_degrees: float,
	initial_spin_sign: float,
) -> void:
	position = initial_position
	velocity = initial_velocity
	horizontal_heading = initial_horizontal_heading.normalized()
	orientation = initial_orientation.orthonormalized()
	self.initial_forward_speed_mps = initial_forward_speed_mps
	charge = initial_charge
	release_bank_degrees = initial_release_bank_degrees
	launch_pitch_degrees = initial_launch_pitch_degrees
	spin_sign = initial_spin_sign
	flight_phase = 0.0
	bank_degrees = initial_release_bank_degrees * initial_spin_sign
	target_bank_degrees = bank_degrees
	launch_pitch_stability_bias_degrees = 0.0
	travel_distance_meters = 0.0
	elapsed_time = 0.0
	tick = 0
	lifecycle = Lifecycle.FLYING


func copy() -> ArcadeFlightState:
	var copied_state := ArcadeFlightState.new(
		position,
		velocity,
		horizontal_heading,
		orientation,
		initial_forward_speed_mps,
		charge,
		release_bank_degrees,
		launch_pitch_degrees,
		spin_sign,
	)
	copied_state.flight_phase = flight_phase
	copied_state.bank_degrees = bank_degrees
	copied_state.target_bank_degrees = target_bank_degrees
	copied_state.launch_pitch_stability_bias_degrees = launch_pitch_stability_bias_degrees
	copied_state.travel_distance_meters = travel_distance_meters
	copied_state.elapsed_time = elapsed_time
	copied_state.tick = tick
	copied_state.lifecycle = lifecycle
	return copied_state
