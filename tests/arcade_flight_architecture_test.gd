extends SceneTree

const SIMULATION_TIMESTEP := ArcadeFlightSimulator.FIXED_TIMESTEP_SECONDS
const SIMULATION_TICKS := 30


func _init() -> void:
	var profile := _create_profile()
	var validation_errors := profile.validate()
	if not validation_errors.is_empty():
		fail("Architecture fixture profile is invalid: %s" % ", ".join(validation_errors))
		return

	var simulator := ArcadeFlightSimulator.new()
	var environment := ArcadeFlightEnvironment.new()
	var level_command := _create_command(0.0)
	var uphill_command := _create_command(20.0)
	var downhill_command := _create_command(-20.0)
	var level_state := simulator.launch(level_command, profile)
	var uphill_state := simulator.launch(uphill_command, profile)
	var downhill_state := simulator.launch(downhill_command, profile)

	if uphill_state.launch_pitch_stability_bias_degrees <= 0.0:
		fail("Uphill launch did not shift the profile toward overstable behavior.")
		return
	if downhill_state.launch_pitch_stability_bias_degrees >= 0.0:
		fail("Downhill launch did not shift the profile toward understable behavior.")
		return

	var level_step := simulator.step(level_state, profile, SIMULATION_TIMESTEP, environment)
	var uphill_step := simulator.step(uphill_state, profile, SIMULATION_TIMESTEP, environment)
	var downhill_step := simulator.step(downhill_state, profile, SIMULATION_TIMESTEP, environment)
	if not (
		_target_bank(uphill_step) > _target_bank(level_step)
		and _target_bank(level_step) > _target_bank(downhill_step)
	):
		fail("Launch pitch did not produce the expected uphill-to-downhill stability ordering.")
		return

	var first_run := simulate(simulator, profile, level_state, environment)
	var second_run := simulate(simulator, profile, level_state, environment)
	if first_run.position.distance_to(second_run.position) > 0.000001 \
		or not is_equal_approx(first_run.flight_phase, second_run.flight_phase) \
		or first_run.tick != second_run.tick:
		fail("Arcade flight architecture is not deterministic for matching inputs.")
		return
	if not _is_finite_state(first_run):
		fail("Arcade flight architecture produced a non-finite state.")
		return

	profile.maximum_travel_distance_meters = 0.1
	var range_limited_state := simulator.step(level_state, profile, SIMULATION_TIMESTEP, environment)
	if range_limited_state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
		fail("Arcade flight range envelope ended an airborne state: distance=%.3f lifecycle=%d." % [
			range_limited_state.travel_distance_meters,
			range_limited_state.lifecycle,
		])
		return
	var phase_complete_state := level_state
	for _step in range(241):
		phase_complete_state = simulator.step(
			phase_complete_state,
			profile,
			SIMULATION_TIMESTEP,
			environment,
		)
	if phase_complete_state.flight_phase < 1.0 \
		or phase_complete_state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
		fail("Arcade phase completion ended an airborne state: phase=%.3f lifecycle=%d." % [
			phase_complete_state.flight_phase,
			phase_complete_state.lifecycle,
		])
		return
	if not _test_neutral_mid_draft():
		return
	if not _test_utility_driver_draft():
		return
	if not _test_beat_in_distance_driver_draft():
		return

	print("ARCADE_FLIGHT_ARCHITECTURE ticks=%d phase=%.3f target_bank=[down=%.3f level=%.3f up=%.3f]" % [
		first_run.tick,
		first_run.flight_phase,
		downhill_step.target_bank_degrees,
		level_step.target_bank_degrees,
		_target_bank(uphill_step),
	])
	quit(0)


func _create_profile() -> ArcadeFlightProfile:
	var profile := ArcadeFlightProfile.new()
	profile.profile_id = &"architecture_fixture"
	profile.stability = ArcadeFlightProfile.Stability.NEUTRAL
	profile.base_forward_speed_mps = 18.0
	profile.phase_duration_seconds = 2.0
	profile.maximum_travel_distance_meters = 100.0
	profile.maximum_bank_degrees = 45.0
	profile.bank_response_degrees_per_second = 180.0
	profile.maximum_heading_turn_degrees_per_second = 90.0
	profile.maximum_launch_pitch_degrees = 30.0
	profile.speed_multiplier_by_charge = _create_curve([Vector2(0.0, 0.5), Vector2(1.0, 1.0)])
	profile.glide_multiplier_by_charge = _create_curve([Vector2(0.0, 0.5), Vector2(1.0, 1.0)])
	profile.phase_rate_multiplier_by_charge = _create_curve([Vector2(0.0, 1.0), Vector2(1.0, 1.0)])
	profile.speed_multiplier_by_phase = _create_curve([Vector2(0.0, 1.0), Vector2(1.0, 0.5)])
	profile.bank_bias_degrees_by_phase = _create_curve([Vector2(0.0, 0.0), Vector2(1.0, 0.0)])
	profile.vertical_acceleration_mps2_by_phase = _create_curve([Vector2(0.0, 9.81), Vector2(1.0, 9.81)])
	profile.stability_bank_degrees_by_launch_pitch = _create_curve([
		Vector2(0.0, -12.0),
		Vector2(0.5, 0.0),
		Vector2(1.0, 12.0),
	])
	return profile


func _create_curve(points: Array[Vector2]) -> Curve:
	var curve := Curve.new()
	curve.min_value = -90.0
	curve.max_value = 90.0
	for point in points:
		curve.add_point(
			point,
			0.0,
			0.0,
			Curve.TangentMode.TANGENT_LINEAR,
			Curve.TangentMode.TANGENT_LINEAR,
		)
	return curve


func _create_command(launch_pitch_degrees: float) -> ArcadeThrowCommand:
	return ArcadeThrowCommand.new(
		Vector3(0.0, 10.0, 0.0),
		Vector3.FORWARD,
		0.5,
		0.0,
		launch_pitch_degrees,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_RIGHT,
	)


func simulate(
	simulator: ArcadeFlightSimulator,
	profile: ArcadeFlightProfile,
	initial_state: ArcadeFlightState,
	environment: ArcadeFlightEnvironment,
) -> ArcadeFlightState:
	var state := initial_state.copy()
	for _step in range(SIMULATION_TICKS):
		state = simulator.step(state, profile, SIMULATION_TIMESTEP, environment)
	return state


func _test_neutral_mid_draft() -> bool:
	const PROFILE_PATH := "res://data/discs/neutral_mid_arcade_draft.tres"
	const RELEASE_BANK_DEGREES := 20.0
	const TERMINAL_TICKS := 361
	const MID_FLIGHT_TICK := 180
	const LATERAL_TOLERANCE_METERS := 0.001
	var profile := load(PROFILE_PATH) as ArcadeFlightProfile
	if profile == null:
		fail("Neutral mid draft profile could not be loaded: %s" % PROFILE_PATH)
		return false
	if profile.stability != ArcadeFlightProfile.Stability.NEUTRAL:
		fail("Neutral mid draft profile is not marked neutral.")
		return false
	var validation_errors := profile.validate()
	if not validation_errors.is_empty():
		fail("Neutral mid draft profile is invalid: %s" % ", ".join(validation_errors))
		return false

	var simulator := ArcadeFlightSimulator.new()
	var environment := ArcadeFlightEnvironment.new()
	var flat_command := ArcadeThrowCommand.new(
		Vector3(0.0, 1.5, 0.0),
		Vector3.FORWARD,
		1.0,
		0.0,
		0.0,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_RIGHT,
	)
	var hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.spin_direction,
	)
	var anhyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		-RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.spin_direction,
	)
	var mirrored_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		flat_command.launch_pitch_degrees,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_LEFT,
	)
	var line_states: Array[ArcadeFlightState] = [
		simulator.launch(flat_command, profile),
		simulator.launch(flat_command, profile),
		simulator.launch(hyzer_command, profile),
		simulator.launch(anhyzer_command, profile),
		simulator.launch(mirrored_flat_command, profile),
	]
	var initial_anhyzer_bank := line_states[3].bank_degrees
	var midpoint_flat_state := line_states[0].copy()
	for _step in range(TERMINAL_TICKS):
		for state_index in line_states.size():
			line_states[state_index] = simulator.step(
				line_states[state_index],
				profile,
				SIMULATION_TIMESTEP,
				environment,
			)
		if _step + 1 == MID_FLIGHT_TICK:
			midpoint_flat_state = line_states[0].copy()

	var flat_state := line_states[0]
	var repeated_flat_state := line_states[1]
	var hyzer_state := line_states[2]
	var anhyzer_state := line_states[3]
	var mirrored_flat_state := line_states[4]
	for state in line_states:
		if not _is_finite_state(state):
			fail("Neutral mid draft produced a non-finite state.")
			return false
		if state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
			fail("Neutral mid draft left airborne flight without a collision result.")
			return false
	if flat_state.position.distance_to(repeated_flat_state.position) > LATERAL_TOLERANCE_METERS:
		fail("Neutral mid flat release was not repeatable within %.3f m." % LATERAL_TOLERANCE_METERS)
		return false

	var natural_finish_sign := signf(flat_state.position.x)
	if absf(flat_state.position.x) <= LATERAL_TOLERANCE_METERS:
		fail("Neutral mid flat release has no readable natural finish direction.")
		return false
	var flat_natural_finish_distance := flat_state.position.x * natural_finish_sign
	var hyzer_natural_finish_distance := hyzer_state.position.x * natural_finish_sign
	var anhyzer_natural_finish_distance := anhyzer_state.position.x * natural_finish_sign
	if not (
		hyzer_natural_finish_distance > flat_natural_finish_distance
		and flat_natural_finish_distance > anhyzer_natural_finish_distance
	):
		fail("Neutral mid releases did not order from held hyzer through flat to anhyzer.")
		return false
	if not (
		absf(flat_state.position.x) < absf(hyzer_state.position.x)
		and absf(flat_state.position.x) < absf(anhyzer_state.position.x)
	):
		fail("Neutral mid flat release was not the straightest lateral line.")
		return false
	if hyzer_state.bank_degrees <= 0.0:
		fail("Neutral mid hyzer did not hold its hyzer bank.")
		return false
	if absf(anhyzer_state.bank_degrees) >= absf(initial_anhyzer_bank):
		fail("Neutral mid anhyzer did not settle toward flat.")
		return false
	if absf(flat_state.position.x + mirrored_flat_state.position.x) > LATERAL_TOLERANCE_METERS:
		fail("Neutral mid flat release did not mirror laterally with spin direction.")
		return false
	print("ARCADE_NEUTRAL_MID_DRAFT profile=%s terminal_time=%.3fs hyzer=[travel=%.3fm lateral=%.3fm bank=%.3fdeg] flat_mid=[time=%.3fs travel=%.3fm lateral=%.3fm bank=%.3fdeg] flat_terminal=[travel=%.3fm lateral=%.3fm bank=%.3fdeg] anhyzer=[travel=%.3fm lateral=%.3fm bank=%.3fdeg]" % [
		profile.profile_id,
		flat_state.elapsed_time,
		hyzer_state.travel_distance_meters,
		hyzer_state.position.x,
		hyzer_state.bank_degrees,
		midpoint_flat_state.elapsed_time,
		midpoint_flat_state.travel_distance_meters,
		midpoint_flat_state.position.x,
		midpoint_flat_state.bank_degrees,
		flat_state.travel_distance_meters,
		flat_state.position.x,
		flat_state.bank_degrees,
		anhyzer_state.travel_distance_meters,
		anhyzer_state.position.x,
		anhyzer_state.bank_degrees,
	])
	return true


func _test_utility_driver_draft() -> bool:
	const PROFILE_PATH := "res://data/discs/utility_driver_arcade_draft.tres"
	const RELEASE_BANK_DEGREES := 20.0
	const TERMINAL_TICKS := 325
	const LATERAL_TOLERANCE_METERS := 0.001
	var profile := load(PROFILE_PATH) as ArcadeFlightProfile
	if profile == null:
		fail("Utility-driver draft profile could not be loaded: %s" % PROFILE_PATH)
		return false
	if profile.stability != ArcadeFlightProfile.Stability.OVERSTABLE:
		fail("Utility-driver draft profile is not marked overstable.")
		return false
	var validation_errors := profile.validate()
	if not validation_errors.is_empty():
		fail("Utility-driver draft profile is invalid: %s" % ", ".join(validation_errors))
		return false

	var simulator := ArcadeFlightSimulator.new()
	var environment := ArcadeFlightEnvironment.new()
	var flat_command := ArcadeThrowCommand.new(
		Vector3(0.0, 1.5, 0.0),
		Vector3.FORWARD,
		1.0,
		0.0,
		0.0,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_RIGHT,
	)
	var hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.spin_direction,
	)
	var anhyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		-RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.spin_direction,
	)
	var mirrored_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		flat_command.launch_pitch_degrees,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_LEFT,
	)
	var line_states: Array[ArcadeFlightState] = [
		simulator.launch(flat_command, profile),
		simulator.launch(flat_command, profile),
		simulator.launch(hyzer_command, profile),
		simulator.launch(anhyzer_command, profile),
		simulator.launch(mirrored_flat_command, profile),
	]
	var initial_anhyzer_bank := line_states[3].bank_degrees
	for _step in range(TERMINAL_TICKS):
		for state_index in line_states.size():
			line_states[state_index] = simulator.step(
				line_states[state_index],
				profile,
				SIMULATION_TIMESTEP,
				environment,
			)

	var flat_state := line_states[0]
	var repeated_flat_state := line_states[1]
	var hyzer_state := line_states[2]
	var anhyzer_state := line_states[3]
	var mirrored_flat_state := line_states[4]
	for state in line_states:
		if not _is_finite_state(state):
			fail("Utility-driver draft produced a non-finite state.")
			return false
		if state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
			fail("Utility-driver draft left airborne flight without a collision result.")
			return false
	if flat_state.position.distance_to(repeated_flat_state.position) > LATERAL_TOLERANCE_METERS:
		fail("Utility-driver flat release was not repeatable within %.3f m." % LATERAL_TOLERANCE_METERS)
		return false

	var natural_finish_sign := signf(flat_state.position.x)
	if absf(flat_state.position.x) <= LATERAL_TOLERANCE_METERS:
		fail("Utility-driver flat release has no readable natural finish direction.")
		return false
	var flat_natural_finish_distance := flat_state.position.x * natural_finish_sign
	var hyzer_natural_finish_distance := hyzer_state.position.x * natural_finish_sign
	var anhyzer_natural_finish_distance := anhyzer_state.position.x * natural_finish_sign
	if not (
		hyzer_natural_finish_distance > flat_natural_finish_distance
		and flat_natural_finish_distance > anhyzer_natural_finish_distance
	):
		fail("Utility-driver releases did not order from spike hyzer through flat to flex.")
		return false
	if not (
		hyzer_state.bank_degrees > flat_state.bank_degrees
		and flat_state.bank_degrees > 0.0
	):
		fail("Utility-driver hyzer and flat release did not finish toward the natural side.")
		return false
	if initial_anhyzer_bank >= 0.0 or anhyzer_state.bank_degrees <= 0.0:
		fail("Utility-driver anhyzer did not flex back through flat.")
		return false
	if absf(flat_state.position.x + mirrored_flat_state.position.x) > LATERAL_TOLERANCE_METERS:
		fail("Utility-driver flat release did not mirror laterally with spin direction.")
		return false
	print("ARCADE_UTILITY_DRIVER_DRAFT profile=%s time=%.3fs hyzer=[travel=%.3fm lateral=%.3fm bank=%.3fdeg] flat=[travel=%.3fm lateral=%.3fm bank=%.3fdeg] anhyzer=[travel=%.3fm lateral=%.3fm bank=%.3fdeg]" % [
		profile.profile_id,
		flat_state.elapsed_time,
		hyzer_state.travel_distance_meters,
		hyzer_state.position.x,
		hyzer_state.bank_degrees,
		flat_state.travel_distance_meters,
		flat_state.position.x,
		flat_state.bank_degrees,
		anhyzer_state.travel_distance_meters,
		anhyzer_state.position.x,
		anhyzer_state.bank_degrees,
	])
	return true


func _test_beat_in_distance_driver_draft() -> bool:
	const PROFILE_PATH := "res://data/discs/beat_in_distance_driver_arcade_draft.tres"
	const RELEASE_BANK_DEGREES := 20.0
	const UPHILL_LAUNCH_PITCH_DEGREES := 20.0
	const TERMINAL_TICKS := 385
	const LATERAL_TOLERANCE_METERS := 0.001
	var profile := load(PROFILE_PATH) as ArcadeFlightProfile
	if profile == null:
		fail("Beat-in distance-driver draft profile could not be loaded: %s" % PROFILE_PATH)
		return false
	if profile.stability != ArcadeFlightProfile.Stability.UNDERSTABLE:
		fail("Beat-in distance-driver draft profile is not marked understable.")
		return false
	var validation_errors := profile.validate()
	if not validation_errors.is_empty():
		fail("Beat-in distance-driver draft profile is invalid: %s" % ", ".join(validation_errors))
		return false

	var simulator := ArcadeFlightSimulator.new()
	var environment := ArcadeFlightEnvironment.new()
	var flat_command := ArcadeThrowCommand.new(
		Vector3(0.0, 1.5, 0.0),
		Vector3.FORWARD,
		1.0,
		0.0,
		0.0,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_RIGHT,
	)
	var hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.spin_direction,
	)
	var anhyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		-RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.spin_direction,
	)
	var mirrored_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		flat_command.launch_pitch_degrees,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_LEFT,
	)
	var uphill_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		UPHILL_LAUNCH_PITCH_DEGREES,
		flat_command.spin_direction,
	)
	var line_states: Array[ArcadeFlightState] = [
		simulator.launch(flat_command, profile),
		simulator.launch(flat_command, profile),
		simulator.launch(hyzer_command, profile),
		simulator.launch(anhyzer_command, profile),
		simulator.launch(mirrored_flat_command, profile),
		simulator.launch(uphill_flat_command, profile),
	]
	var initial_hyzer_bank := line_states[2].bank_degrees
	for _step in range(TERMINAL_TICKS):
		for state_index in line_states.size():
			line_states[state_index] = simulator.step(
				line_states[state_index],
				profile,
				SIMULATION_TIMESTEP,
				environment,
			)

	var flat_state := line_states[0]
	var repeated_flat_state := line_states[1]
	var hyzer_state := line_states[2]
	var anhyzer_state := line_states[3]
	var mirrored_flat_state := line_states[4]
	var uphill_flat_state := line_states[5]
	for state in line_states:
		if not _is_finite_state(state):
			fail("Beat-in distance-driver draft produced a non-finite state.")
			return false
	if flat_state.lifecycle != ArcadeFlightState.Lifecycle.FLYING \
		or hyzer_state.lifecycle != ArcadeFlightState.Lifecycle.FLYING \
		or uphill_flat_state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
		fail("Beat-in distance-driver flat, hyzer, or uphill-flat release entered roller state.")
		return false
	if anhyzer_state.lifecycle != ArcadeFlightState.Lifecycle.ROLLER_ENTRY:
		fail("Beat-in distance-driver anhyzer did not enter roller state.")
		return false
	if anhyzer_state.flight_phase < profile.roller_entry_phase \
		or absf(anhyzer_state.bank_degrees) < profile.roller_entry_bank_degrees:
		fail("Beat-in distance-driver roller entry ignored its configured phase or bank gate.")
		return false
	if flat_state.position.distance_to(repeated_flat_state.position) > LATERAL_TOLERANCE_METERS:
		fail("Beat-in distance-driver flat release was not repeatable within %.3f m." % LATERAL_TOLERANCE_METERS)
		return false
	if absf(hyzer_state.bank_degrees) >= absf(initial_hyzer_bank):
		fail("Beat-in distance-driver hyzer did not flip back toward flat.")
		return false
	if flat_state.bank_degrees >= -10.0:
		fail("Beat-in distance-driver flat release did not turn toward its understable side.")
		return false
	if not (
		uphill_flat_state.bank_degrees > flat_state.bank_degrees
		and absf(uphill_flat_state.position.x) < absf(flat_state.position.x)
	):
		fail("Beat-in distance-driver uphill flat release did not straighten its level turning line.")
		return false
	if absf(flat_state.position.x + mirrored_flat_state.position.x) > LATERAL_TOLERANCE_METERS:
		fail("Beat-in distance-driver flat release did not mirror laterally with spin direction.")
		return false
	print("ARCADE_BEAT_IN_DISTANCE_DRIVER_DRAFT profile=%s hyzer=[travel=%.3fm lateral=%.3fm bank=%.3fdeg lifecycle=%d] flat=[travel=%.3fm lateral=%.3fm bank=%.3fdeg lifecycle=%d] uphill_flat=[travel=%.3fm lateral=%.3fm bank=%.3fdeg lifecycle=%d] anhyzer=[travel=%.3fm lateral=%.3fm bank=%.3fdeg phase=%.3f lifecycle=%d]" % [
		profile.profile_id,
		hyzer_state.travel_distance_meters,
		hyzer_state.position.x,
		hyzer_state.bank_degrees,
		hyzer_state.lifecycle,
		flat_state.travel_distance_meters,
		flat_state.position.x,
		flat_state.bank_degrees,
		flat_state.lifecycle,
		uphill_flat_state.travel_distance_meters,
		uphill_flat_state.position.x,
		uphill_flat_state.bank_degrees,
		uphill_flat_state.lifecycle,
		anhyzer_state.travel_distance_meters,
		anhyzer_state.position.x,
		anhyzer_state.bank_degrees,
		anhyzer_state.flight_phase,
		anhyzer_state.lifecycle,
	])
	return true


func _target_bank(state: ArcadeFlightState) -> float:
	return state.target_bank_degrees


func _is_finite_state(state: ArcadeFlightState) -> bool:
	return is_finite(state.position.x) \
		and is_finite(state.position.y) \
		and is_finite(state.position.z) \
		and is_finite(state.velocity.x) \
		and is_finite(state.velocity.y) \
		and is_finite(state.velocity.z) \
		and is_finite(state.flight_phase) \
		and is_finite(state.bank_degrees)


func fail(message: String) -> void:
	push_error(message)
	quit(1)
