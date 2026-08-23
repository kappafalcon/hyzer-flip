class_name ArcadeFlightState
extends RefCounted

## Complete replayable state for the pure arcade airborne simulator.

enum Lifecycle {
	FLYING,
	ROLLER_ENTRY,
	EXHAUSTED,
}

## Launch values are retained so every snapshot has the inputs needed for a
## deterministic replay.
var initial_forward_speed_mps: float
var charge: float
var release_bank_degrees: float
var launch_pitch_degrees: float
var fade_sign: float

## These values evolve as the simulator advances fixed ticks.
var position: Vector3
var velocity: Vector3
var horizontal_heading: Vector3
var orientation: Basis
var flight_phase: float
var bank_degrees: float
var target_bank_degrees: float
var launch_pitch_stability_bias_degrees: float
var travel_distance_meters: float
var elapsed_time: float
var tick: int
var lifecycle: Lifecycle = Lifecycle.FLYING


func _init(
	initial_position: Vector3,
	initial_velocity: Vector3,
	initial_horizontal_heading: Vector3,
	initial_orientation: Basis,
	initial_forward_speed_mps: float,
	initial_charge: float,
	initial_release_bank_degrees: float,
	initial_launch_pitch_degrees: float,
	initial_fade_sign: float,
) -> void:
	position = initial_position
	velocity = initial_velocity
	horizontal_heading = initial_horizontal_heading.normalized()
	orientation = initial_orientation.orthonormalized()
	self.initial_forward_speed_mps = initial_forward_speed_mps
	charge = initial_charge
	release_bank_degrees = initial_release_bank_degrees
	launch_pitch_degrees = initial_launch_pitch_degrees
	fade_sign = initial_fade_sign
	flight_phase = 0.0
	bank_degrees = initial_release_bank_degrees * initial_fade_sign
	target_bank_degrees = bank_degrees
	launch_pitch_stability_bias_degrees = 0.0
	travel_distance_meters = 0.0
	elapsed_time = 0.0
	tick = 0
	lifecycle = Lifecycle.FLYING


## Returns an independent snapshot that the simulator can safely advance.
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
		fade_sign,
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


## Overwrites this reusable state buffer with a distinct source snapshot.
##
## This supports allocation-free fixed stepping while leaving this state
## unchanged. The source must not be this same state.
func overwrite_from(source: ArcadeFlightState) -> void:
	assert(source != self, "Arcade flight state source must differ from its output buffer.")
	initial_forward_speed_mps = source.initial_forward_speed_mps
	charge = source.charge
	release_bank_degrees = source.release_bank_degrees
	launch_pitch_degrees = source.launch_pitch_degrees
	fade_sign = source.fade_sign
	position = source.position
	velocity = source.velocity
	horizontal_heading = source.horizontal_heading
	orientation = source.orientation
	flight_phase = source.flight_phase
	bank_degrees = source.bank_degrees
	target_bank_degrees = source.target_bank_degrees
	launch_pitch_stability_bias_degrees = source.launch_pitch_stability_bias_degrees
	travel_distance_meters = source.travel_distance_meters
	elapsed_time = source.elapsed_time
	tick = source.tick
	lifecycle = source.lifecycle
