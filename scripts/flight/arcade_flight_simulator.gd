class_name ArcadeFlightSimulator
extends RefCounted

## Pure fixed-step arcade airborne simulation.
##
## The simulator owns no Nodes, input, scene transforms, physics queries, or
## network state. It advances an intended airborne segment; a future adapter
## will query and resolve collision before presentation consumes the result.

const MIN_VECTOR_LENGTH_SQUARED := 0.000001
const FIXED_TIMESTEP_SECONDS := 1.0 / 120.0


func launch(
	command: ArcadeThrowCommand,
	profile: ArcadeFlightProfile,
) -> ArcadeFlightState:
	assert(command.is_valid(), "Arcade throw command is invalid.")
	assert(profile.is_valid(), "Arcade flight profile is invalid.")
	var launch_direction := _build_launch_direction(command)
	var initial_speed := (
		profile.base_forward_speed_mps
		* profile.sample_charge_speed_multiplier(command.charge)
	)
	var initial_velocity := launch_direction * initial_speed
	var initial_orientation := _build_orientation(
		initial_velocity,
		0.0,
		command.launch_pitch_degrees,
	)
	var state := ArcadeFlightState.new(
		command.origin,
		initial_velocity,
		command.horizontal_forward,
		initial_orientation,
		initial_speed,
		command.charge,
		command.release_bank_degrees,
		command.launch_pitch_degrees,
		command.get_spin_sign(),
	)
	state.launch_pitch_stability_bias_degrees = profile.sample_launch_pitch_stability_bias(
		command.launch_pitch_degrees
	)
	state.target_bank_degrees = _calculate_target_bank_degrees(state, profile)
	state.bank_degrees = state.target_bank_degrees
	state.orientation = _build_orientation(
		initial_velocity,
		state.bank_degrees,
		state.launch_pitch_degrees,
	)
	return state


func step(
	state: ArcadeFlightState,
	profile: ArcadeFlightProfile,
	delta: float,
	environment: ArcadeFlightEnvironment = null,
) -> ArcadeFlightState:
	if delta <= 0.0 or state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
		return state.copy()
	assert(profile.is_valid(), "Arcade flight profile is invalid.")
	var flight_environment := environment if environment != null else ArcadeFlightEnvironment.new()
	assert(flight_environment.is_valid(), "Arcade flight environment is invalid.")

	var next_state := state.copy()
	var phase_rate := (
		profile.sample_charge_phase_rate_multiplier(state.charge)
		/ profile.phase_duration_seconds
	)
	next_state.flight_phase = min(state.flight_phase + phase_rate * delta, 1.0)
	next_state.launch_pitch_stability_bias_degrees = profile.sample_launch_pitch_stability_bias(
		state.launch_pitch_degrees
	)
	next_state.target_bank_degrees = _calculate_target_bank_degrees(next_state, profile)
	next_state.bank_degrees = move_toward(
		state.bank_degrees,
		next_state.target_bank_degrees,
		profile.bank_response_degrees_per_second * delta,
	)
	next_state.horizontal_heading = _advance_heading(next_state, profile, delta)

	var speed := (
		next_state.initial_forward_speed_mps
		* profile.sample_phase_speed_multiplier(next_state.flight_phase)
	)
	var glide_acceleration := (
		profile.sample_phase_vertical_acceleration(next_state.flight_phase)
		* profile.sample_charge_glide_multiplier(next_state.charge)
		* cos(deg_to_rad(absf(next_state.bank_degrees)))
	)
	var vertical_speed := state.velocity.y + (
		glide_acceleration - flight_environment.gravity_mps2
	) * delta
	next_state.velocity = next_state.horizontal_heading * speed
	next_state.velocity.y = vertical_speed

	var previous_position := state.position
	next_state.position += next_state.velocity * delta
	next_state.travel_distance_meters += previous_position.distance_to(next_state.position)
	next_state.orientation = _build_orientation(
		next_state.velocity,
		next_state.bank_degrees,
		next_state.launch_pitch_degrees,
	)
	next_state.elapsed_time += delta
	next_state.tick += 1
	_apply_terminal_lifecycle(next_state, profile)
	return next_state


func _build_launch_direction(command: ArcadeThrowCommand) -> Vector3:
	var right_axis := command.horizontal_forward.cross(Vector3.UP).normalized()
	return command.horizontal_forward.rotated(
		right_axis,
		deg_to_rad(command.launch_pitch_degrees),
	).normalized()


func _calculate_target_bank_degrees(
	state: ArcadeFlightState,
	profile: ArcadeFlightProfile,
) -> float:
	var mold_relative_bank := (
		state.release_bank_degrees
		+ profile.sample_phase_bank_bias_degrees(state.flight_phase)
		+ state.launch_pitch_stability_bias_degrees
	)
	return clampf(
		mold_relative_bank * state.spin_sign,
		-profile.maximum_bank_degrees,
		profile.maximum_bank_degrees,
	)


func _advance_heading(
	state: ArcadeFlightState,
	profile: ArcadeFlightProfile,
	delta: float,
) -> Vector3:
	var bank_ratio := state.bank_degrees / profile.maximum_bank_degrees
	# A phase defines a bounded steering impulse. Airborne integration can
	# continue after phase completion, but must not keep accumulating a turn
	# long enough for a lofted disc to curl back toward its release point.
	var remaining_phase := 1.0 - state.flight_phase
	var turn_phase_multiplier := remaining_phase * remaining_phase
	var turn_angle := deg_to_rad(
		profile.maximum_heading_turn_degrees_per_second
		* bank_ratio
		* turn_phase_multiplier
		* delta
	)
	return state.horizontal_heading.rotated(Vector3.UP, turn_angle).normalized()


func _build_orientation(
	velocity: Vector3,
	bank_degrees: float,
	nose_pitch_degrees: float,
) -> Basis:
	var forward := Vector3(velocity.x, 0.0, velocity.z)
	if forward.length_squared() <= MIN_VECTOR_LENGTH_SQUARED:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right_axis := forward.cross(Vector3.UP)
	if right_axis.length_squared() <= MIN_VECTOR_LENGTH_SQUARED:
		right_axis = Vector3.RIGHT
	else:
		right_axis = right_axis.normalized()
	var up_axis := right_axis.cross(forward).normalized()
	var orientation := Basis(right_axis, up_axis, -forward)
	# Positive bank turns a -Z-facing heading left around world up. Roll the
	# presentation basis toward that turn side so the disc visibly leans left.
	orientation = Basis(forward, deg_to_rad(-bank_degrees)) * orientation
	return (Basis(right_axis, deg_to_rad(nose_pitch_degrees)) * orientation).orthonormalized()


func _apply_terminal_lifecycle(
	state: ArcadeFlightState,
	profile: ArcadeFlightProfile,
) -> void:
	if profile.roller_entry_phase <= 1.0 \
		and state.flight_phase >= profile.roller_entry_phase \
		and absf(state.bank_degrees) >= profile.roller_entry_bank_degrees:
		state.lifecycle = ArcadeFlightState.Lifecycle.ROLLER_ENTRY
