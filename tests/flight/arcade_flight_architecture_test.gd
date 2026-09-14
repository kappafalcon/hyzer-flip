extends SceneTree

const SIMULATION_TIMESTEP := ArcadeFlightSimulator.FIXED_TIMESTEP_SECONDS
const SIMULATION_TICKS := 30
const MAXIMUM_LAB_TRAVEL_DISTANCE_METERS := 30.48
const MAXIMUM_LAB_FLIGHT_TIMES_BY_PROFILE_SECONDS := {
	"res://data/discs/neutral_mid_arcade_draft.tres": 0.9,
	"res://data/discs/utility_driver_arcade_draft.tres": 0.8,
	"res://data/discs/beat_in_distance_driver_arcade_draft.tres": 0.9,
}
const MINIMUM_UTILITY_DRIVER_GROUND_FADE_METERS := 3.0


func _init() -> void:
	var profile := _create_profile()
	var validation_errors := profile.validate()
	if not validation_errors.is_empty():
		fail("Architecture fixture profile is invalid: %s" % ", ".join(validation_errors))
		return
	var no_uphill_fade_profile := _create_profile()
	no_uphill_fade_profile.stability_bank_degrees_by_launch_pitch = _create_curve([
		Vector2(0.0, -12.0),
		Vector2(0.5, 0.0),
		Vector2(1.0, 0.0),
	])
	if no_uphill_fade_profile.is_valid():
		fail("Flight profiles without uphill fade bias must be rejected.")
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
	var buffered_output := level_state.copy()
	simulator.step_into(
		level_state,
		profile,
		SIMULATION_TIMESTEP,
		environment,
		buffered_output,
	)
	if level_state.tick != 0 \
		or buffered_output.position.distance_to(level_step.position) > 0.000001 \
		or buffered_output.velocity.distance_to(level_step.velocity) > 0.000001 \
		or not is_equal_approx(buffered_output.flight_phase, level_step.flight_phase) \
		or not is_equal_approx(buffered_output.target_bank_degrees, level_step.target_bank_degrees) \
		or buffered_output.tick != level_step.tick:
		fail("Preallocated arcade flight output differed from an ordinary simulation step.")
		return
	var uphill_step := simulator.step(uphill_state, profile, SIMULATION_TIMESTEP, environment)
	var downhill_step := simulator.step(downhill_state, profile, SIMULATION_TIMESTEP, environment)
	if not is_zero_approx(_target_bank(uphill_step)) \
		or uphill_step.horizontal_heading.distance_to(uphill_state.horizontal_heading) > 0.000001:
		fail("An ascending release applied turn/fade before reaching its apex.")
		return
	var post_apex_uphill_state := uphill_state.copy()
	post_apex_uphill_state.velocity.y = 0.0
	var post_apex_uphill_step := simulator.step(
		post_apex_uphill_state,
		profile,
		SIMULATION_TIMESTEP,
		environment,
	)
	if not (
		_target_bank(post_apex_uphill_step) > _target_bank(level_step)
		and _target_bank(level_step) > _target_bank(downhill_step)
	):
		fail("Launch pitch did not produce the expected post-apex stability ordering.")
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
	if not _test_full_charge_lab_range_cap():
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


func _test_full_charge_lab_range_cap() -> bool:
	const PROFILE_PATHS := [
		"res://data/discs/neutral_mid_arcade_draft.tres",
		"res://data/discs/utility_driver_arcade_draft.tres",
		"res://data/discs/beat_in_distance_driver_arcade_draft.tres",
	]
	const MAXIMUM_TICKS := 2400
	var simulator := ArcadeFlightSimulator.new()
	for profile_path in PROFILE_PATHS:
		var profile := load(profile_path) as ArcadeFlightProfile
		var command := ArcadeThrowCommand.new(
			Vector3(0.0, 1.5, 0.0),
			Vector3.FORWARD,
			1.0,
			0.0,
			2.0,
			ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
		)
		var state := simulator.launch(command, profile)
		var reached_ground := false
		var ground_crossing_position := Vector3.ZERO
		for _tick in range(MAXIMUM_TICKS):
			var previous_state := state
			state = simulator.step(state, profile, SIMULATION_TIMESTEP)
			if state.position.y <= 0.0:
				reached_ground = true
				var ground_crossing_fraction := previous_state.position.y / (
					previous_state.position.y - state.position.y
				)
				ground_crossing_position = previous_state.position.lerp(
					state.position,
					ground_crossing_fraction,
				)
				break
			if state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
				fail("%s entered a non-airborne lifecycle before reaching the lab ground plane." % profile.profile_id)
				return false
		if not reached_ground:
			fail("%s did not reach the lab ground plane within %d ticks." % [
				profile.profile_id,
				MAXIMUM_TICKS,
			])
			return false
		if state.travel_distance_meters >= MAXIMUM_LAB_TRAVEL_DISTANCE_METERS:
			fail("%s exceeded the %.2f m (100 ft) lab flight cap: %.3f m." % [
				profile.profile_id,
				MAXIMUM_LAB_TRAVEL_DISTANCE_METERS,
				state.travel_distance_meters,
			])
			return false
		var maximum_flight_time_seconds := float(
			MAXIMUM_LAB_FLIGHT_TIMES_BY_PROFILE_SECONDS[profile_path]
		)
		if state.elapsed_time > maximum_flight_time_seconds:
			fail("%s exceeded its %.2f s lab arrival-time cap: %.3f s." % [
				profile.profile_id,
				maximum_flight_time_seconds,
				state.elapsed_time,
			])
			return false
		if profile.profile_id == &"utility_driver_draft" \
			and -ground_crossing_position.x < MINIMUM_UTILITY_DRIVER_GROUND_FADE_METERS:
			fail("%s reached the lab ground plane only %.3f m into its left fade; expected at least %.3f m." % [
				profile.profile_id,
				-ground_crossing_position.x,
				MINIMUM_UTILITY_DRIVER_GROUND_FADE_METERS,
			])
			return false
		print("ARCADE_RANGE_CAP profile=%s travel=%.3fm lateral=%.3fm time=%.3fs" % [
			profile.profile_id,
			state.travel_distance_meters,
			ground_crossing_position.x,
			state.elapsed_time,
		])
	return true


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
		ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
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
	const OPENING_HALF_PHASE := 0.5
	const MAXIMUM_OPENING_BANK_BIAS_DEGREES := 0.5
	const MINIMUM_LATE_BANK_BIAS_DEGREES := 20.0
	const MINIMUM_HYZER_FINISH_DISTANCE_METERS := 10.0
	const MINIMUM_HYZER_FINISH_ADVANTAGE_METERS := 9.5
	const UPHILL_HYZER_LAUNCH_PITCH_DEGREES := 20.0
	const MINIMUM_UPHILL_HYZER_APEX_GAIN_METERS := 0.5
	const MINIMUM_UPHILL_HYZER_LATE_BANK_DEGREES := 30.0
	const POST_APEX_BANK_SAMPLE_TICKS := 45
	const MAXIMUM_UPHILL_HYZER_TICKS := 180
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
	if absf(profile.sample_phase_bank_bias_degrees(OPENING_HALF_PHASE)) > MAXIMUM_OPENING_BANK_BIAS_DEGREES:
		fail("Neutral mid begins banking %.3f° before its opening-half limit of %.3f°." % [
			profile.sample_phase_bank_bias_degrees(OPENING_HALF_PHASE),
			MAXIMUM_OPENING_BANK_BIAS_DEGREES,
		])
		return false
	if profile.sample_phase_bank_bias_degrees(0.75) < MINIMUM_LATE_BANK_BIAS_DEGREES:
		fail("Neutral mid late bank bias %.3f° is below its %.3f° finish threshold." % [
			profile.sample_phase_bank_bias_degrees(0.75),
			MINIMUM_LATE_BANK_BIAS_DEGREES,
		])
		return false

	var simulator := ArcadeFlightSimulator.new()
	var environment := ArcadeFlightEnvironment.new()
	var flat_command := ArcadeThrowCommand.new(
		Vector3(0.0, 1.5, 0.0),
		Vector3.FORWARD,
		1.0,
		0.0,
		0.0,
		ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
	)
	var hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.fade_direction,
	)
	var uphill_hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		UPHILL_HYZER_LAUNCH_PITCH_DEGREES,
		flat_command.fade_direction,
	)
	var anhyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		-RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.fade_direction,
	)
	var mirrored_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		flat_command.launch_pitch_degrees,
		ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_RIGHT,
	)
	var line_states: Array[ArcadeFlightState] = [
		simulator.launch(flat_command, profile),
		simulator.launch(flat_command, profile),
		simulator.launch(hyzer_command, profile),
		simulator.launch(anhyzer_command, profile),
		simulator.launch(mirrored_flat_command, profile),
	]
	var initial_anhyzer_bank := line_states[3].bank_degrees
	var uphill_hyzer_state := simulator.launch(uphill_hyzer_command, profile)
	var uphill_hyzer_peak_height := uphill_hyzer_state.position.y
	var uphill_hyzer_reached_apex := false
	var uphill_hyzer_reached_ground := false
	var uphill_hyzer_recorded_late_descent := false
	var uphill_hyzer_post_apex_ticks := 0
	var uphill_hyzer_late_bank_degrees := 0.0
	var uphill_hyzer_late_vertical_speed := 0.0
	for _step in range(MAXIMUM_UPHILL_HYZER_TICKS):
		var previous_uphill_hyzer_state := uphill_hyzer_state
		uphill_hyzer_state = simulator.step(
			uphill_hyzer_state,
			profile,
			SIMULATION_TIMESTEP,
			environment,
		)
		uphill_hyzer_peak_height = maxf(
			uphill_hyzer_peak_height,
			uphill_hyzer_state.position.y,
		)
		if previous_uphill_hyzer_state.velocity.y > 0.0 \
			and uphill_hyzer_state.velocity.y <= 0.0:
			uphill_hyzer_reached_apex = true
		if uphill_hyzer_reached_apex and not uphill_hyzer_recorded_late_descent:
			upright_hyzer_post_apex_ticks += 1
		if uphill_hyzer_post_apex_ticks >= POST_APEX_BANK_SAMPLE_TICKS \
			and not uphill_hyzer_recorded_late_descent:
			uphill_hyzer_late_bank_degrees = uphill_hyzer_state.bank_degrees
			uphill_hyzer_late_vertical_speed = uphill_hyzer_state.velocity.y
			uphill_hyzer_recorded_late_descent = true
		if uphill_hyzer_state.position.y <= 0.0:
			uphill_hyzer_reached_ground = true
			break
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
	if hyzer_natural_finish_distance < MINIMUM_HYZER_FINISH_DISTANCE_METERS:
		fail("Neutral mid hyzer finish %.3f m is below its %.3f m bite threshold." % [
			hyzer_natural_finish_distance,
			MINIMUM_HYZER_FINISH_DISTANCE_METERS,
		])
		return false
	if hyzer_natural_finish_distance - flat_natural_finish_distance \
		< MINIMUM_HYZER_FINISH_ADVANTAGE_METERS:
		fail("Neutral mid hyzer gained only %.3f m over flat; expected at least %.3f m of finish advantage." % [
			hyzer_natural_finish_distance - flat_natural_finish_distance,
			MINIMUM_HYZER_FINISH_ADVANTAGE_METERS,
		])
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
	if not uphill_hyzer_reached_apex \
		or uphill_hyzer_peak_height < uphill_hyzer_command.origin.y + MINIMUM_UPHILL_HYZER_APEX_GAIN_METERS:
		fail("Neutral mid uphill hyzer did not reach its %.3f m apex gain." % MINIMUM_UPHILL_HYZER_APEX_GAIN_METERS)
		return false
	if not uphill_hyzer_recorded_late_descent \
		or uphill_hyzer_late_bank_degrees < MINIMUM_UPHILL_HYZER_LATE_BANK_DEGREES \
		or uphill_hyzer_late_vertical_speed >= 0.0:
		fail("Neutral mid uphill hyzer did not bank and descend through its late phase.")
		return false
	if not uphill_hyzer_reached_ground:
		fail("Neutral mid uphill hyzer did not reach the visual ground plane within %d ticks." % MAXIMUM_UPHILL_HYZER_TICKS)
		return false
	if absf(flat_state.position.x + mirrored_flat_state.position.x) > LATERAL_TOLERANCE_METERS:
		fail("Neutral mid flat release did not mirror laterally with fade direction.")
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
	const MINIMUM_TERMINAL_SPEED_MULTIPLIER := 0.95
	const MINIMUM_FLAT_HOOK_DISTANCE_METERS := 9.0
	const MINIMUM_HYZER_FINISH_BANK_DEGREES := 70.0
	const MINIMUM_HYZER_BANK_ADVANTAGE_DEGREES := 10.0
	const MAXIMUM_PRE_APEX_BANK_DEGREES := 5.0
	const MINIMUM_POST_APEX_BANK_DEGREES := 65.0
	const MAXIMUM_NON_INVERTING_BANK_DEGREES := 89.0
	const UPHILL_LAUNCH_PITCH_DEGREES := 20.0
	const SPIKE_DESCENT_CHECK_PHASE := 0.65
	const MAXIMUM_SPIKE_HYZER_TICKS := 240
	const MINIMUM_SPIKE_HYZER_APEX_GAIN_METERS := 0.5
	const POST_APEX_TRANSITION_CHECK_PHASE := 0.4
	const MAXIMUM_POST_APEX_TRANSITION_BANK_DEGREES := 60.0
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
	if profile.sample_phase_speed_multiplier(1.0) < MINIMUM_TERMINAL_SPEED_MULTIPLIER:
		fail("Utility-driver terminal speed multiplier %.3f is below its %.3f carry threshold." % [
			profile.sample_phase_speed_multiplier(1.0),
			MINIMUM_TERMINAL_SPEED_MULTIPLIER,
		])
		return false
	if absf(profile.sample_phase_bank_bias_degrees(0.2)) > MAXIMUM_PRE_APEX_BANK_DEGREES:
		fail("Utility-driver banked %.3f° before its %.3f° apex-phase limit." % [
			profile.sample_phase_bank_bias_degrees(0.2),
			MAXIMUM_PRE_APEX_BANK_DEGREES,
		])
		return false
	if profile.sample_phase_bank_bias_degrees(0.45) < MINIMUM_POST_APEX_BANK_DEGREES:
		fail("Utility-driver post-apex bank %.3f° is below its %.3f° spike-fade threshold." % [
			profile.sample_phase_bank_bias_degrees(0.45),
			MINIMUM_POST_APEX_BANK_DEGREES,
		])
		return false

	var simulator := ArcadeFlightSimulator.new()
	var environment := ArcadeFlightEnvironment.new()
	var flat_command := ArcadeThrowCommand.new(
		Vector3(0.0, 1.5, 0.0),
		Vector3.FORWARD,
		1.0,
		0.0,
		0.0,
		ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
	)
	var hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.fade_direction,
	)
	var anhyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		-RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.fade_direction,
	)
	var mirrored_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		flat_command.launch_pitch_degrees,
		ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_RIGHT,
	)
	var spike_hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		UPHILL_LAUNCH_PITCH_DEGREES,
		flat_command.fade_direction,
	)
	var line_states: Array[ArcadeFlightState] = [
		simulator.launch(flat_command, profile),
		simulator.launch(flat_command, profile),
		simulator.launch(hyzer_command, profile),
		simulator.launch(anhyzer_command, profile),
		simulator.launch(mirrored_flat_command, profile),
	]
	var initial_anhyzer_bank := line_states[3].bank_degrees
	var spike_hyzer_state := simulator.launch(spike_hyzer_command, profile)
	var spike_hyzer_peak_height := spike_hyzer_state.position.y
	var spike_hyzer_reached_apex := false
	var spike_hyzer_reached_ground := false
	var spike_hyzer_recorded_descent := false
	var spike_hyzer_late_fade_vertical_speed := 0.0
	for _step in range(MAXIMUM_SPIKE_HYZER_TICKS):
		var previous_spike_hyzer_state := spike_hyzer_state
		spike_hyzer_state = simulator.step(
			spike_hyzer_state,
			profile,
			SIMULATION_TIMESTEP,
			environment,
		)
		spike_hyzer_peak_height = maxf(
			spike_hyzer_peak_height,
			spike_hyzer_state.position.y,
		)
		if previous_spike_hyzer_state.velocity.y > 0.0 \
			and spike_hyzer_state.velocity.y <= 0.0:
			spike_hyzer_reached_apex = true
		if not spike_hyzer_recorded_descent \
			and spike_hyzer_state.flight_phase >= SPIKE_DESCENT_CHECK_PHASE:
			spike_hyzer_late_fade_vertical_speed = spike_hyzer_state.velocity.y
			spike_hyzer_recorded_descent = true
		if spike_hyzer_state.position.y <= 0.0:
			spike_hyzer_reached_ground = true
			break
	var transition_state := simulator.launch(flat_command, profile)
	for _step in range(TERMINAL_TICKS):
		for state_index in line_states.size():
			line_states[state_index] = simulator.step(
				line_states[state_index],
				profile,
				SIMULATION_TIMESTEP,
				environment,
			)
		if transition_state.flight_phase < POST_APEX_TRANSITION_CHECK_PHASE:
			transition_state = simulator.step(
				transition_state,
				profile,
				SIMULATION_TIMESTEP,
				environment,
			)

	var flat_state := line_states[0]
	var repeated_flat_state := line_states[1]
	var hyzer_state := line_states[2]
	var anhyzer_state := line_states[3]
	var mirrored_flat_state := line_states[4]
	if not spike_hyzer_reached_apex \
		or spike_hyzer_peak_height < flat_command.origin.y + MINIMUM_SPIKE_HYZER_APEX_GAIN_METERS:
		fail("Utility-driver spike hyzer did not form a readable uphill apex: peak=%.3f m." % [
			spike_hyzer_peak_height,
		])
		return false
	if not spike_hyzer_recorded_descent or spike_hyzer_late_fade_vertical_speed >= 0.0:
		fail("Utility-driver spike hyzer was not descending during its late fade: vertical_speed=%.3f m/s." % [
			spike_hyzer_late_fade_vertical_speed,
		])
		return false
	if not spike_hyzer_reached_ground:
		fail("Utility-driver spike hyzer did not return to the visual ground plane within %d ticks." % [
			MAXIMUM_SPIKE_HYZER_TICKS,
		])
		return false
	if transition_state.bank_degrees >= MAXIMUM_POST_APEX_TRANSITION_BANK_DEGREES:
		fail("Utility-driver rolled %.3f° into its post-apex fade; expected a progressive transition below %.3f°." % [
			transition_state.bank_degrees,
			MAXIMUM_POST_APEX_TRANSITION_BANK_DEGREES,
		])
		return false
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
	if hyzer_state.bank_degrees < MINIMUM_HYZER_FINISH_BANK_DEGREES:
		fail("Utility-driver hyzer finish bank %.3f° is below its %.3f° corner-hook threshold." % [
			hyzer_state.bank_degrees,
			MINIMUM_HYZER_FINISH_BANK_DEGREES,
		])
		return false
	if hyzer_state.bank_degrees - flat_state.bank_degrees < MINIMUM_HYZER_BANK_ADVANTAGE_DEGREES:
		fail("Utility-driver hyzer finish bank %.3f° did not preserve a %.3f° advantage over flat %.3f°." % [
			hyzer_state.bank_degrees,
			MINIMUM_HYZER_BANK_ADVANTAGE_DEGREES,
			flat_state.bank_degrees,
		])
		return false
	if maxf(
		absf(flat_state.bank_degrees),
		maxf(absf(hyzer_state.bank_degrees), absf(anhyzer_state.bank_degrees)),
	) >= MAXIMUM_NON_INVERTING_BANK_DEGREES:
		fail("Utility-driver reached an inverting bank angle at or above %.3f°." % [
			MAXIMUM_NON_INVERTING_BANK_DEGREES,
		])
		return false
	if flat_natural_finish_distance < MINIMUM_FLAT_HOOK_DISTANCE_METERS:
		fail("Utility-driver flat finish %.3f m is below its %.3f m corner-hook threshold." % [
			flat_natural_finish_distance,
			MINIMUM_FLAT_HOOK_DISTANCE_METERS,
		])
		return false
	if initial_anhyzer_bank >= 0.0 or anhyzer_state.bank_degrees <= 0.0:
		fail("Utility-driver anhyzer did not flex back through flat.")
		return false
	if absf(flat_state.position.x + mirrored_flat_state.position.x) > LATERAL_TOLERANCE_METERS:
		fail("Utility-driver flat release did not mirror laterally with fade direction.")
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
		ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
	)
	var hyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.fade_direction,
	)
	var anhyzer_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		-RELEASE_BANK_DEGREES,
		flat_command.launch_pitch_degrees,
		flat_command.fade_direction,
	)
	var mirrored_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		flat_command.launch_pitch_degrees,
		ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_RIGHT,
	)
	var uphill_flat_command := ArcadeThrowCommand.new(
		flat_command.origin,
		flat_command.horizontal_forward,
		flat_command.charge,
		flat_command.release_bank_degrees,
		UPHILL_LAUNCH_PITCH_DEGREES,
		flat_command.fade_direction,
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
		fail("Beat-in distance-driver flat release did not mirror laterally with fade direction.")
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
