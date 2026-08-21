extends SceneTree

const SIMULATION_TIMESTEP := 1.0 / 120.0
const MAX_SIMULATION_TICKS := 120 * 30
const METERS_TO_FEET := 3.28084
const RANGE_MIN_METERS := 109.7
const RANGE_MAX_METERS := 134.1
const FLIGHT_TIME_MIN_SECONDS := 5.0
const FLIGHT_TIME_MAX_SECONDS := 6.5
const MINIMUM_FLIP_NORMAL_X := 0.2
const MAXIMUM_FADE_LANDING_NORMAL_X := -0.15
const MINIMUM_UPRIGHT_NORMAL_Y := 0.1
const ROLL_DIRECTION_EPSILON := deg_to_rad(0.1)


func _init() -> void:
	var disc_data: DiscData = load("res://data/discs/ol_reliable.tres")
	var data_errors := disc_data.validate()
	if not data_errors.is_empty():
		fail("Invalid Ol Reliable data: %s" % ", ".join(data_errors))
		return

	var initial_state := FlightLaunch.create_state(
		Vector3(0.0, 1.5, 0.0),
		Basis.IDENTITY,
		ThrowParameters.new(60.0, 1300.0, 8.0, 10.0, 0.0),
	)
	var simulator := FlightSimulator.new()
	var first_run := simulate_to_ground(simulator, disc_data, initial_state)
	var repeat_run := simulate_to_ground(simulator, disc_data, initial_state)

	if not first_run["landed"] or not first_run["finite"] \
		or not repeat_run["landed"] or not repeat_run["finite"]:
		fail("Ol Reliable fixture did not produce a finite ground impact.")
		return
	if not is_equal_approx(first_run["range_meters"], repeat_run["range_meters"]):
		fail("Ol Reliable fixture is not repeatable.")
		return
	print("OL_RELIABLE_FLIGHT range=%.6f m (%.2f ft), time=%.6f s, peak=%.6f m, landing_spin=%.1f rpm, alpha=[%.2f, %.2f] deg, flip_normal_x=%.3f, min_normal_y=%.3f, landing_normal_x=%.3f, roll_direction_changes=%d" % [
		first_run["range_meters"],
		first_run["range_meters"] * METERS_TO_FEET,
		first_run["elapsed_time"],
		first_run["max_height_meters"],
		first_run["landing_spin_rate"] * 60.0 / TAU,
		first_run["minimum_angle_of_attack_degrees"],
		first_run["maximum_angle_of_attack_degrees"],
		first_run["maximum_normal_x"],
		first_run["minimum_normal_y"],
		first_run["landing_normal_x"],
		first_run["roll_direction_changes"],
	])
	if first_run["range_meters"] < RANGE_MIN_METERS \
		or first_run["range_meters"] > RANGE_MAX_METERS:
		fail("Ol Reliable %.3f m is outside the 360-440 ft release envelope." % first_run["range_meters"])
		return
	if first_run["elapsed_time"] < FLIGHT_TIME_MIN_SECONDS \
		or first_run["elapsed_time"] > FLIGHT_TIME_MAX_SECONDS:
		fail("Ol Reliable flight time is outside the 5.0-6.5 s release envelope.")
		return
	if first_run["maximum_normal_x"] < MINIMUM_FLIP_NORMAL_X:
		fail("Ol Reliable did not flip past flat from its hyzer release.")
		return
	if first_run["minimum_normal_y"] < MINIMUM_UPRIGHT_NORMAL_Y:
		fail("Ol Reliable rolled through upside-down instead of finishing its fade upright.")
		return
	if first_run["landing_normal_x"] > MAXIMUM_FADE_LANDING_NORMAL_X:
		fail("Ol Reliable did not finish in the configured fade direction.")
		return
	if first_run["roll_direction_changes"] != 1:
		fail("Ol Reliable must have exactly one turn-to-fade roll reversal.")
		return
	quit(0)


func simulate_to_ground(
	simulator: FlightSimulator,
	disc_data: DiscData,
	initial_state: FlightState,
) -> Dictionary:
	var state := initial_state.copy()
	var max_height := state.position.y
	var maximum_normal_x := state.orientation.y.x
	var minimum_normal_y := state.orientation.y.y
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
		maximum_normal_x = max(maximum_normal_x, state.orientation.y.x)
		minimum_normal_y = min(minimum_normal_y, state.orientation.y.y)
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
				"landing_spin_rate": lerp(
					previous_state.spin_rate,
					state.spin_rate,
					impact_fraction,
				),
				"maximum_normal_x": maximum_normal_x,
				"minimum_normal_y": minimum_normal_y,
				"minimum_angle_of_attack_degrees": rad_to_deg(minimum_angle_of_attack),
				"maximum_angle_of_attack_degrees": rad_to_deg(maximum_angle_of_attack),
				"landing_normal_x": state.orientation.y.x,
				"roll_direction_changes": roll_direction_changes,
			}

	return {"landed": false, "finite": true}


func fail(message: String) -> void:
	push_error(message)
	quit(1)
