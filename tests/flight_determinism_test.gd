extends SceneTree

const SIMULATION_TIMESTEP := 1.0 / 120.0
const MAX_SIMULATION_TICKS := 120 * 30
const METERS_TO_FEET := 3.28084
const CALIBRATED_RANGE_MIN_METERS := 115.8
const CALIBRATED_RANGE_MAX_METERS := 131.1
const HIGH_HYZER_RANGE_MIN_METERS := 76.2
const HIGH_HYZER_RANGE_MAX_METERS := 106.7
const MINIMUM_HYZER_RANGE_REDUCTION_METERS := 20.0
const MAX_UNBOUNDED_RELEASE_RANGE_METERS := 152.4
const MAX_UNBOUNDED_RELEASE_TIME_SECONDS := 7.5
const MAX_ROLL_DIRECTION_CHANGES := 1
const ROLL_DIRECTION_EPSILON := deg_to_rad(0.1)


func _init() -> void:
	var disc_data: DiscData = load("res://data/discs/prototype_distance_driver.tres")
	var data_errors := disc_data.validate()
	if not data_errors.is_empty():
		fail("Invalid reference disc data: %s" % ", ".join(data_errors))
		return

	var throw := ThrowParameters.new(60.0, 1300.0, 8.0, 10.0, 0.0)
	var initial_state := FlightLaunch.create_state(
		Vector3(0.0, 1.5, 0.0),
		Basis.IDENTITY,
		throw,
	)
	var simulator := FlightSimulator.new()
	var first_run := simulate_to_ground(simulator, disc_data, initial_state)
	var second_run := simulate_to_ground(simulator, disc_data, initial_state)
	var explicit_calm_state := simulator.step(
		initial_state,
		disc_data,
		SIMULATION_TIMESTEP,
		FlightEnvironment.new(),
	)
	var tailwind_state := simulator.step(
		initial_state,
		disc_data,
		SIMULATION_TIMESTEP,
		FlightEnvironment.new(Vector3(0.0, 0.0, -5.0)),
	)
	var high_hyzer_throw := ThrowParameters.new(60.0, 1300.0, 20.0, 10.0, 0.0)
	var high_hyzer_state := FlightLaunch.create_state(
		Vector3(0.0, 1.5, 0.0),
		Basis.IDENTITY,
		high_hyzer_throw,
	)
	var high_hyzer_run := simulate_to_ground(simulator, disc_data, high_hyzer_state)
	var high_hyzer_repeat_run := simulate_to_ground(
		simulator,
		disc_data,
		high_hyzer_state,
	)
	var neutral_state := FlightLaunch.create_state(
		Vector3(0.0, 1.5, 0.0),
		Basis.IDENTITY,
		ThrowParameters.new(60.0, 1300.0, 0.0, 10.0, 0.0),
	)
	var anhyzer_state := FlightLaunch.create_state(
		Vector3(0.0, 1.5, 0.0),
		Basis.IDENTITY,
		ThrowParameters.new(60.0, 1300.0, -10.0, 10.0, 0.0),
	)
	var neutral_run := simulate_to_ground(simulator, disc_data, neutral_state)
	var anhyzer_run := simulate_to_ground(simulator, disc_data, anhyzer_state)

	if not first_run["landed"]:
		fail("Reference throw did not reach the ground within 30 seconds.")
		return
	if not first_run["finite"] or not second_run["finite"]:
		fail("Reference throw produced a non-finite simulation state.")
		return
	if not high_hyzer_run["landed"] or not high_hyzer_run["finite"] \
		or not high_hyzer_repeat_run["landed"] \
		or not high_hyzer_repeat_run["finite"]:
		fail("20-degree hyzer fixture did not produce a finite ground impact.")
		return
	if not neutral_run["landed"] or not neutral_run["finite"] \
		or not anhyzer_run["landed"] or not anhyzer_run["finite"]:
		fail("Neutral or -10-degree release fixture did not produce a finite ground impact.")
		return
	if not is_equal_approx(first_run["range_meters"], second_run["range_meters"]):
		fail("Reference throw is not repeatable.")
		return
	if tailwind_state.air_speed >= explicit_calm_state.air_speed - 4.5:
		fail("FlightEnvironment wind velocity did not change air-relative speed.")
		return
	if first_run["landing_spin_rate"] >= initial_state.spin_rate \
		or first_run["landing_spin_rate"] < 0.0:
		fail("Reference throw did not apply bounded spin decay.")
		return
	print("DETERMINISTIC_FLIGHT range=%.6f m (%.2f ft), time=%.6f s, peak=%.6f m, landing_spin=%.1f rpm, alpha=[%.2f, %.2f] deg, ticks=%d" % [
		first_run["range_meters"],
		first_run["range_meters"] * METERS_TO_FEET,
		first_run["elapsed_time"],
		first_run["max_height_meters"],
		first_run["landing_spin_rate"] * 60.0 / TAU,
		first_run["minimum_angle_of_attack_degrees"],
		first_run["maximum_angle_of_attack_degrees"],
		first_run["ticks"],
	])
	print("WIND_BOUNDARY calm_air_speed=%.3f m/s, tailwind_air_speed=%.3f m/s" % [
		explicit_calm_state.air_speed,
		tailwind_state.air_speed,
	])
	print("HIGH_HYZER_FLIGHT range=%.6f m (%.2f ft), time=%.6f s, peak=%.6f m, landing_spin=%.1f rpm, alpha=[%.2f, %.2f] deg, ticks=%d" % [
		high_hyzer_run["range_meters"],
		high_hyzer_run["range_meters"] * METERS_TO_FEET,
		high_hyzer_run["elapsed_time"],
		high_hyzer_run["max_height_meters"],
		high_hyzer_run["landing_spin_rate"] * 60.0 / TAU,
		high_hyzer_run["minimum_angle_of_attack_degrees"],
		high_hyzer_run["maximum_angle_of_attack_degrees"],
		high_hyzer_run["ticks"],
	])
	print("NEUTRAL_FLIGHT range=%.6f m (%.2f ft), time=%.6f s, roll_direction_changes=%d" % [
		neutral_run["range_meters"],
		neutral_run["range_meters"] * METERS_TO_FEET,
		neutral_run["elapsed_time"],
		neutral_run["roll_direction_changes"],
	])
	print("ANHYZER_FLIGHT range=%.6f m (%.2f ft), time=%.6f s, roll_direction_changes=%d" % [
		anhyzer_run["range_meters"],
		anhyzer_run["range_meters"] * METERS_TO_FEET,
		anhyzer_run["elapsed_time"],
		anhyzer_run["roll_direction_changes"],
	])
	if first_run["range_meters"] < CALIBRATED_RANGE_MIN_METERS \
		or first_run["range_meters"] > CALIBRATED_RANGE_MAX_METERS:
		fail("Calibrated fixture %.3f m is outside the 380-430 ft release envelope." % first_run["range_meters"])
		return
	if not is_equal_approx(
		high_hyzer_run["range_meters"],
		high_hyzer_repeat_run["range_meters"],
	):
		fail("20-degree hyzer fixture is not repeatable.")
		return
	if high_hyzer_run["range_meters"] < HIGH_HYZER_RANGE_MIN_METERS \
		or high_hyzer_run["range_meters"] > HIGH_HYZER_RANGE_MAX_METERS:
		fail("20-degree hyzer fixture %.3f m is outside the 250-350 ft fade envelope." % high_hyzer_run["range_meters"])
		return
	if high_hyzer_run["range_meters"] > first_run["range_meters"] - MINIMUM_HYZER_RANGE_REDUCTION_METERS:
		fail("20-degree hyzer fixture did not produce a materially shorter fade line.")
		return
	for fixture in [neutral_run, anhyzer_run]:
		if fixture["range_meters"] > MAX_UNBOUNDED_RELEASE_RANGE_METERS \
			or fixture["elapsed_time"] > MAX_UNBOUNDED_RELEASE_TIME_SECONDS:
			fail("Neutral or -10-degree release exceeded the 500 ft / 7.5 s glide envelope.")
			return
		if fixture["roll_direction_changes"] > MAX_ROLL_DIRECTION_CHANGES:
			fail("Release fixture reversed roll direction more than once.")
			return
	if first_run["max_height_meters"] <= 1.5:
		fail("Reference throw never gained height.")
		return

	quit(0)


func simulate_to_ground(
	simulator: FlightSimulator,
	disc_data: DiscData,
	initial_state: FlightState,
) -> Dictionary:
	var state := initial_state.copy()
	var max_height := state.position.y
	var minimum_angle_of_attack := state.angle_of_attack
	var maximum_angle_of_attack := state.angle_of_attack
	var previous_roll_direction := 0
	var roll_direction_changes := 0

	for _step in range(MAX_SIMULATION_TICKS):
		var previous_state := state
		state = simulator.step(state, disc_data, SIMULATION_TIMESTEP)
		if not is_finite(state.position.x) \
			or not is_finite(state.position.y) \
			or not is_finite(state.position.z) \
			or not is_finite(state.velocity.x) \
			or not is_finite(state.velocity.y) \
			or not is_finite(state.velocity.z):
			return {"landed": false, "finite": false}
		max_height = max(max_height, state.position.y)
		minimum_angle_of_attack = min(minimum_angle_of_attack, state.angle_of_attack)
		maximum_angle_of_attack = max(maximum_angle_of_attack, state.angle_of_attack)
		if abs(state.roll_rate) > ROLL_DIRECTION_EPSILON:
			var roll_direction := 1 if state.roll_rate > 0.0 else -1
			if previous_roll_direction != 0 and roll_direction != previous_roll_direction:
				roll_direction_changes += 1
			previous_roll_direction = roll_direction
		if previous_state.position.y > 0.0 and state.position.y <= 0.0:
			var impact_fraction := previous_state.position.y / (
				previous_state.position.y - state.position.y
			)
			var impact_position := previous_state.position.lerp(
				state.position,
				impact_fraction,
			)
			return {
				"landed": true,
				"finite": true,
				"range_meters": Vector2(impact_position.x, impact_position.z).length(),
				"elapsed_time": lerp(
					previous_state.elapsed_time,
					state.elapsed_time,
					impact_fraction,
				),
				"max_height_meters": max_height,
				"minimum_angle_of_attack_degrees": rad_to_deg(minimum_angle_of_attack),
				"maximum_angle_of_attack_degrees": rad_to_deg(maximum_angle_of_attack),
				"landing_spin_rate": lerp(
					previous_state.spin_rate,
					state.spin_rate,
					impact_fraction,
				),
				"roll_direction_changes": roll_direction_changes,
				"ticks": state.tick,
			}

	return {"landed": false, "finite": true}


func fail(message: String) -> void:
	push_error(message)
	quit(1)
