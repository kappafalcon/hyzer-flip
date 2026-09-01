extends Node3D

## Isolated visual harness and pure fixed-step prototype for flight-model v2.
##
## This file intentionally does not reference the existing arcade/aerodynamic
## flight classes. The inner data/state types and static solver functions form
## the prototype boundary; the Node3D code below only drives and presents them.
## Simulation values use SI units, Godot +Y is up, and release forward is -Z.
## Positive bank steers toward -X (the natural-left hyzer/fade side).

enum FlightPhase {
	POWERED_FLIGHT,
	LATE_FLIGHT,
}


class DiscParameters:
	# These are inspectable arcade strength coefficients, not normalized ratings;
	# strongly overstable fade may intentionally exceed 1.0.
	var display_name: String
	var turn_tendency: float
	var turn_resistance: float
	var fade: float
	var color: Color

	func _init(
		initial_display_name: String,
		initial_turn_tendency: float,
		initial_turn_resistance: float,
		initial_fade: float,
		initial_color: Color,
	) -> void:
		display_name = initial_display_name
		turn_tendency = initial_turn_tendency
		turn_resistance = initial_turn_resistance
		fade = initial_fade
		color = initial_color


class FlightState:
	var position := Vector3.ZERO
	var velocity := Vector3.ZERO
	var orientation := Basis.IDENTITY
	var bank_degrees := 0.0
	var phase: FlightPhase = FlightPhase.POWERED_FLIGHT
	var tick := 0
	var elapsed_seconds := 0.0
	var apex_tick := -1
	var apex_position := Vector3.ZERO
	var apex_velocity := Vector3.ZERO

	func copy() -> FlightState:
		var copied := FlightState.new()
		copied.position = position
		copied.velocity = velocity
		copied.orientation = orientation
		copied.bank_degrees = bank_degrees
		copied.phase = phase
		copied.tick = tick
		copied.elapsed_seconds = elapsed_seconds
		copied.apex_tick = apex_tick
		copied.apex_position = apex_position
		copied.apex_velocity = apex_velocity
		return copied


const FIXED_TIMESTEP_SECONDS := 1.0 / 120.0
const GRAVITY_MPS2 := 9.81
const LAUNCH_SPEED_MPS := 22.0
const LAUNCH_PITCH_DEGREES := 15.0
const RELEASE_POSITION := Vector3(0.0, 1.5, 0.0)
const HYZER_RELEASE_DEGREES := 22.0
const ANHYZER_RELEASE_DEGREES := -22.0
const MAX_POWERED_ANHYZER_DEGREES := -55.0
const MAX_LATE_HYZER_DEGREES := 70.0
const TURN_DRIVE_RATE_DEGREES_PER_SECOND := 55.0
const TURN_RESISTANCE_RATE_DEGREES_PER_SECOND := 45.0
const FADE_BANK_RATE_DEGREES_PER_SECOND := 45.0
const HEADING_RATE_DEGREES_PER_SECOND := 90.0
const MAX_SIMULATION_TICKS := 600
const TRACE_INTERVAL_TICKS := 2
const STATE_TOLERANCE := 0.000001
const UTILITY_MINIMUM_FLEX_CLEARANCE_METERS := 2.0
const UTILITY_MAXIMUM_CENTER_FINISH_OFFSET_METERS := 0.5
const UTILITY_MAXIMUM_APEX_ANHYZER_DEGREES := 1.0
const FLEX_COVER_PLANE_Z_METERS := -12.0
const FLEX_COVER_HALF_DEPTH_METERS := 0.15
const FLEX_COVER_RIGHT_EDGE_X_METERS := 0.7
const FLEX_COVER_TOP_Y_METERS := 4.0
const FLEX_COVER_MINIMUM_CLEARANCE_METERS := 0.6

const RELEASE_BANKS := [
	HYZER_RELEASE_DEGREES,
	0.0,
	ANHYZER_RELEASE_DEGREES,
]

var disc_parameters: Array[DiscParameters] = []
var flight_state: FlightState
var active_parameters: DiscParameters
var simulation_accumulator := 0.0
var is_presenting_flight := false
var presentation_position := RELEASE_POSITION
var powered_trace_points := PackedVector3Array()
var late_trace_points := PackedVector3Array()
var verification_landmarks := ""

@onready var disc_visual: Node3D = $DiscVisual
@onready var disc_body: MeshInstance3D = $DiscVisual/DiscBody
@onready var powered_trail_visual: MeshInstance3D = $PoweredTrail
@onready var late_trail_visual: MeshInstance3D = $LateTrail
@onready var apex_marker: MeshInstance3D = $ApexMarker
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var disc_select: OptionButton = $UI/Panel/Margin/Content/DiscRow/DiscSelect
@onready var release_select: OptionButton = $UI/Panel/Margin/Content/ReleaseRow/ReleaseSelect
@onready var parameter_label: Label = $UI/Panel/Margin/Content/ParameterLabel
@onready var status_label: Label = $UI/Panel/Margin/Content/StatusLabel
@onready var verification_label: Label = $UI/Panel/Margin/Content/VerificationLabel


static func create_default_disc_parameters() -> Array[DiscParameters]:
	return [
		(
			DiscParameters
			. new(
				"Overstable / utility",
				0.15,
				1.00,
				2.00,
				Color(0.96, 0.35, 0.22),
			)
		),
		(
			DiscParameters
			. new(
				"Neutral / stable",
				0.45,
				0.50,
				0.35,
				Color(0.20, 0.72, 0.98),
			)
		),
		(
			DiscParameters
			. new(
				"Understable / beat-in",
				0.95,
				0.15,
				0.25,
				Color(0.72, 0.38, 0.96),
			)
		),
	]


func _ready() -> void:
	disc_parameters = create_default_disc_parameters()
	for parameters in disc_parameters:
		disc_select.add_item(parameters.display_name)
	release_select.add_item("Hyzer (+22 degrees)")
	release_select.add_item("Flat (0 degrees)")
	release_select.add_item("Anhyzer (-22 degrees)")
	# Open directly on the visual corner-line test while keeping every release
	# and mold available through the existing controls.
	disc_select.select(0)
	release_select.select(2)
	overview_camera.look_at(Vector3(0.0, 0.5, -15.0), Vector3.UP)

	var verification_failures := _run_prototype_verification()
	if verification_failures.is_empty():
		verification_label.text = "Built-in deterministic matrix: PASS\n%s" % verification_landmarks
	else:
		verification_label.text = (
			"Built-in deterministic matrix: FAIL\n%s" % "\n".join(verification_failures)
		)

	if DisplayServer.get_name() == "headless":
		if verification_failures.is_empty():
			print("ARCADE_FLIGHT_V2_TEST PASS %s" % verification_landmarks)
			get_tree().quit(0)
		else:
			for failure in verification_failures:
				push_error("ARCADE_FLIGHT_V2_TEST: %s" % failure)
			get_tree().quit(1)
		return

	_on_throw_pressed()


func _physics_process(delta: float) -> void:
	if not is_presenting_flight or flight_state == null:
		return
	simulation_accumulator += delta
	var trail_changed := false
	while simulation_accumulator >= FIXED_TIMESTEP_SECONDS and is_presenting_flight:
		var previous_state := flight_state
		flight_state = step_flight(
			previous_state,
			active_parameters,
			FIXED_TIMESTEP_SECONDS,
		)
		simulation_accumulator -= FIXED_TIMESTEP_SECONDS
		presentation_position = flight_state.position

		var reached_apex := (
			previous_state.phase == FlightPhase.POWERED_FLIGHT
			and flight_state.phase == FlightPhase.LATE_FLIGHT
		)
		if reached_apex:
			powered_trace_points.append(flight_state.position)
			late_trace_points.append(flight_state.position)
			apex_marker.position = flight_state.position
			apex_marker.visible = true
			trail_changed = true
		elif flight_state.tick % TRACE_INTERVAL_TICKS == 0:
			if flight_state.phase == FlightPhase.POWERED_FLIGHT:
				powered_trace_points.append(flight_state.position)
			else:
				late_trace_points.append(flight_state.position)
			trail_changed = true

		if previous_state.position.y > 0.0 and flight_state.position.y <= 0.0:
			var ground_fraction := (
				previous_state.position.y / (previous_state.position.y - flight_state.position.y)
			)
			presentation_position = (
				previous_state
				. position
				. lerp(
					flight_state.position,
					ground_fraction,
				)
			)
			late_trace_points.append(presentation_position)
			is_presenting_flight = false
			trail_changed = true

	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		presentation_position,
	)
	if trail_changed:
		_redraw_trails()
	_update_status()


func _on_throw_pressed() -> void:
	var profile_index := clampi(disc_select.selected, 0, disc_parameters.size() - 1)
	var release_index := clampi(release_select.selected, 0, RELEASE_BANKS.size() - 1)
	active_parameters = disc_parameters[profile_index]
	flight_state = launch_flight(active_parameters, RELEASE_BANKS[release_index])
	simulation_accumulator = 0.0
	is_presenting_flight = true
	presentation_position = flight_state.position
	powered_trace_points = PackedVector3Array([flight_state.position])
	late_trace_points = PackedVector3Array()
	apex_marker.visible = false
	var disc_material := disc_body.material_override as StandardMaterial3D
	if disc_material != null:
		disc_material.albedo_color = active_parameters.color
	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		flight_state.position,
	)
	_redraw_trails()
	_update_status()


func _on_reset_pressed() -> void:
	var profile_index := clampi(disc_select.selected, 0, disc_parameters.size() - 1)
	var release_index := clampi(release_select.selected, 0, RELEASE_BANKS.size() - 1)
	active_parameters = disc_parameters[profile_index]
	flight_state = launch_flight(active_parameters, RELEASE_BANKS[release_index])
	simulation_accumulator = 0.0
	is_presenting_flight = false
	presentation_position = flight_state.position
	powered_trace_points = PackedVector3Array()
	late_trace_points = PackedVector3Array()
	apex_marker.visible = false
	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		flight_state.position,
	)
	_redraw_trails()
	_update_status()


func _on_verify_replay_pressed() -> void:
	var profile_index := clampi(disc_select.selected, 0, disc_parameters.size() - 1)
	var release_index := clampi(release_select.selected, 0, RELEASE_BANKS.size() - 1)
	var first_run := _simulate_to_visual_ground(
		disc_parameters[profile_index],
		RELEASE_BANKS[release_index],
	)
	var second_run := _simulate_to_visual_ground(
		disc_parameters[profile_index],
		RELEASE_BANKS[release_index],
	)
	if _trajectories_match(first_run, second_run):
		verification_label.text = (
			"Selected replay: PASS (%d identical fixed ticks)\n%s"
			% [
				first_run.size() - 1,
				verification_landmarks,
			]
		)
	else:
		verification_label.text = "Selected replay: FAIL — state mismatch"


static func launch_flight(
	parameters: DiscParameters,
	release_bank_degrees: float,
	launch_pitch_degrees: float = LAUNCH_PITCH_DEGREES,
	launch_position: Vector3 = RELEASE_POSITION,
	horizontal_forward: Vector3 = Vector3.FORWARD,
	launch_speed_mps: float = LAUNCH_SPEED_MPS,
) -> FlightState:
	assert(parameters != null, "Arcade flight prototype requires explicit disc parameters.")
	assert(
		launch_position.is_finite(), "Arcade flight prototype requires a finite launch position."
	)
	assert(horizontal_forward.is_finite(), "Arcade flight prototype requires a finite heading.")
	assert(
		is_finite(launch_speed_mps) and launch_speed_mps > 0.0,
		"Arcade flight prototype requires a positive finite launch speed.",
	)
	var normalized_horizontal_forward := Vector3(
		horizontal_forward.x,
		0.0,
		horizontal_forward.z,
	)
	assert(
		normalized_horizontal_forward.length_squared() > 0.000001,
		"Arcade flight prototype requires a non-zero horizontal heading.",
	)
	normalized_horizontal_forward = normalized_horizontal_forward.normalized()
	var launched := FlightState.new()
	var launch_pitch_radians := deg_to_rad(launch_pitch_degrees)
	var launch_direction := (
		(
			normalized_horizontal_forward * cos(launch_pitch_radians)
			+ Vector3.UP * sin(launch_pitch_radians)
		)
		. normalized()
	)
	launched.position = launch_position
	launched.velocity = launch_direction * launch_speed_mps
	launched.bank_degrees = release_bank_degrees
	launched.phase = FlightPhase.POWERED_FLIGHT
	launched.orientation = _build_orientation(
		launched.velocity,
		launched.bank_degrees,
	)
	if launched.velocity.y <= 0.0:
		# A level or downward release has no rising segment, so its apex is the
		# release itself and fade may begin on the first simulated tick.
		launched.phase = FlightPhase.LATE_FLIGHT
		launched.apex_tick = 0
		launched.apex_position = launched.position
		launched.apex_velocity = launched.velocity
	return launched


static func step_flight(
	state: FlightState,
	parameters: DiscParameters,
	delta: float,
) -> FlightState:
	var next_state := state.copy()
	if delta <= 0.0:
		return next_state

	if state.phase == FlightPhase.POWERED_FLIGHT:
		# Tendency supplies anhyzer drive. Resistance is evaluated separately
		# and can cancel that drive, but it never creates early fade.
		var turn_drive_rate := parameters.turn_tendency * TURN_DRIVE_RATE_DEGREES_PER_SECOND
		var resisting_rate := parameters.turn_resistance * TURN_RESISTANCE_RATE_DEGREES_PER_SECOND
		var net_turn_rate := turn_drive_rate - resisting_rate
		if net_turn_rate > 0.0:
			next_state.bank_degrees = move_toward(
				state.bank_degrees,
				MAX_POWERED_ANHYZER_DEGREES,
				net_turn_rate * delta,
			)
		elif state.bank_degrees < 0.0:
			# Excess resistance cannot manufacture hyzer/fade before apex, but it
			# can flex an existing anhyzer release back toward flat.
			next_state.bank_degrees = move_toward(
				state.bank_degrees,
				0.0,
				-net_turn_rate * delta,
			)
	else:
		# Fade is deliberately absent from the powered branch and begins on the
		# first complete fixed tick after the vertical apex crossing.
		next_state.bank_degrees = move_toward(
			state.bank_degrees,
			MAX_LATE_HYZER_DEGREES,
			parameters.fade * FADE_BANK_RATE_DEGREES_PER_SECOND * delta,
		)

	var horizontal_velocity := Vector3(state.velocity.x, 0.0, state.velocity.z)
	if horizontal_velocity.length_squared() > 0.000001:
		var yaw_rate_radians := deg_to_rad(
			HEADING_RATE_DEGREES_PER_SECOND * sin(deg_to_rad(next_state.bank_degrees))
		)
		horizontal_velocity = (
			horizontal_velocity
			. rotated(
				Vector3.UP,
				yaw_rate_radians * delta,
			)
		)
		next_state.velocity.x = horizontal_velocity.x
		next_state.velocity.z = horizontal_velocity.z
	next_state.velocity.y = state.velocity.y - GRAVITY_MPS2 * delta
	next_state.position = state.position + next_state.velocity * delta
	next_state.tick = state.tick + 1
	next_state.elapsed_seconds = state.elapsed_seconds + delta
	next_state.orientation = _build_orientation(
		next_state.velocity,
		next_state.bank_degrees,
	)

	if (
		state.phase == FlightPhase.POWERED_FLIGHT
		and state.velocity.y > 0.0
		and next_state.velocity.y <= 0.0
	):
		# The transition changes only the phase and records the landmark. The
		# integrated position, velocity, bank, and orientation remain untouched.
		next_state.phase = FlightPhase.LATE_FLIGHT
		next_state.apex_tick = next_state.tick
		next_state.apex_position = next_state.position
		next_state.apex_velocity = next_state.velocity

	return next_state


static func _build_orientation(velocity: Vector3, bank_degrees: float) -> Basis:
	if velocity.length_squared() <= 0.000001:
		return Basis.IDENTITY
	var forward := velocity.normalized()
	var right := forward.cross(Vector3.UP).normalized()
	if right.length_squared() <= 0.000001:
		right = Vector3.RIGHT
	var local_up := right.cross(forward).normalized()
	var flight_basis := Basis(right, local_up, -forward)
	return (Basis(forward, -deg_to_rad(bank_degrees)) * flight_basis).orthonormalized()


func _redraw_trails() -> void:
	_redraw_trail(powered_trail_visual, powered_trace_points)
	_redraw_trail(late_trail_visual, late_trace_points)


func _redraw_trail(visual: MeshInstance3D, points: PackedVector3Array) -> void:
	var immediate_mesh := visual.mesh as ImmediateMesh
	if immediate_mesh == null:
		return
	immediate_mesh.clear_surfaces()
	if points.size() < 2:
		return
	immediate_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, visual.material_override)
	for point in points:
		immediate_mesh.surface_add_vertex(point)
	immediate_mesh.surface_end()


func _update_status() -> void:
	if flight_state == null or active_parameters == null:
		return
	parameter_label.text = (
		"turn_tendency %.2f   turn_resistance %.2f   fade %.2f"
		% [
			active_parameters.turn_tendency,
			active_parameters.turn_resistance,
			active_parameters.fade,
		]
	)
	var phase_text := "POWERED_FLIGHT — turn active, fade OFF"
	if flight_state.phase == FlightPhase.LATE_FLIGHT:
		phase_text = "LATE_FLIGHT — fade active"
	if not is_presenting_flight and flight_state.position.y <= 0.0:
		phase_text += " — visual ground crossing (no ground state)"
	status_label.text = (
		"%s\nTick %d  time %.3f s  y %.2f m  vy %.2f m/s  bank %.1f degrees"
		% [
			phase_text,
			flight_state.tick,
			flight_state.elapsed_seconds,
			presentation_position.y,
			flight_state.velocity.y,
			flight_state.bank_degrees,
		]
	)


func _simulate_to_visual_ground(
	parameters: DiscParameters,
	release_bank_degrees: float,
) -> Array[FlightState]:
	var trajectory: Array[FlightState] = []
	var state := launch_flight(parameters, release_bank_degrees)
	trajectory.append(state)
	for _tick in range(MAX_SIMULATION_TICKS):
		state = step_flight(state, parameters, FIXED_TIMESTEP_SECONDS)
		trajectory.append(state)
		if state.phase == FlightPhase.LATE_FLIGHT and state.position.y <= 0.0:
			break
	return trajectory


func _run_prototype_verification() -> PackedStringArray:
	var failures := PackedStringArray()
	var trajectories: Array = []
	for parameters in disc_parameters:
		var release_trajectories: Array = []
		for release_bank in RELEASE_BANKS:
			var trajectory := _simulate_to_visual_ground(parameters, release_bank)
			release_trajectories.append(trajectory)
			_verify_trajectory_contract(
				trajectory,
				"%s / %.1f degree release" % [parameters.display_name, release_bank],
				failures,
			)
		trajectories.append(release_trajectories)

	var repeated_understable_flat := _simulate_to_visual_ground(
		disc_parameters[2],
		0.0,
	)
	if not _trajectories_match(trajectories[2][1], repeated_understable_flat):
		failures.append(
			"Identical understable flat inputs did not reproduce the same state sequence."
		)

	var neutral_flat: Array[FlightState] = trajectories[1][1]
	var overstable_flat: Array[FlightState] = trajectories[0][1]
	var overstable_anhyzer: Array[FlightState] = trajectories[0][2]
	var understable_hyzer: Array[FlightState] = trajectories[2][0]
	var understable_flat: Array[FlightState] = trajectories[2][1]
	var overstable_hyzer: Array[FlightState] = trajectories[0][0]
	var neutral_terminal: FlightState = neutral_flat[neutral_flat.size() - 1]
	var overstable_terminal: FlightState = overstable_flat[overstable_flat.size() - 1]
	var overstable_anhyzer_terminal: FlightState = overstable_anhyzer[overstable_anhyzer.size() - 1]
	var understable_terminal: FlightState = understable_flat[understable_flat.size() - 1]
	var understable_hyzer_apex := _apex_state(understable_hyzer)
	var understable_flat_apex := _apex_state(understable_flat)
	var overstable_hyzer_apex := _apex_state(overstable_hyzer)
	var overstable_anhyzer_apex := _apex_state(overstable_anhyzer)
	var overstable_anhyzer_maximum_x := 0.0
	var overstable_anhyzer_maximum_x_tick := 0
	var flex_cover_crossing_position := Vector3.ZERO
	var flex_cover_crossing_found := false
	var flex_cover_crossing_was_powered := false
	var flex_cover_minimum_x := INF
	var flex_cover_front_z := FLEX_COVER_PLANE_Z_METERS + FLEX_COVER_HALF_DEPTH_METERS
	var flex_cover_back_z := FLEX_COVER_PLANE_Z_METERS - FLEX_COVER_HALF_DEPTH_METERS
	for state_index in range(overstable_anhyzer.size()):
		var state: FlightState = overstable_anhyzer[state_index]
		if state.position.x > overstable_anhyzer_maximum_x:
			overstable_anhyzer_maximum_x = state.position.x
			overstable_anhyzer_maximum_x_tick = state.tick
		if state.position.z <= flex_cover_front_z and state.position.z >= flex_cover_back_z:
			flex_cover_minimum_x = minf(flex_cover_minimum_x, state.position.x)
		if state_index == 0:
			continue
		var previous: FlightState = overstable_anhyzer[state_index - 1]
		for cover_sample_z in [
			flex_cover_front_z,
			FLEX_COVER_PLANE_Z_METERS,
			flex_cover_back_z,
		]:
			if previous.position.z <= cover_sample_z or state.position.z > cover_sample_z:
				continue
			var crossing_fraction: float = (
				(cover_sample_z - previous.position.z) / (state.position.z - previous.position.z)
			)
			var sampled_position: Vector3 = (
				previous
				. position
				. lerp(
					state.position,
					crossing_fraction,
				)
			)
			flex_cover_minimum_x = minf(flex_cover_minimum_x, sampled_position.x)
			if cover_sample_z == FLEX_COVER_PLANE_Z_METERS:
				flex_cover_crossing_position = sampled_position
				flex_cover_crossing_found = true
				flex_cover_crossing_was_powered = (
					previous.phase == FlightPhase.POWERED_FLIGHT
					and state.phase == FlightPhase.POWERED_FLIGHT
				)

	if (
		absf(neutral_terminal.position.x) >= 2.5
		or absf(neutral_terminal.position.x) >= absf(overstable_terminal.position.x)
		or absf(neutral_terminal.position.x) >= absf(understable_terminal.position.x)
	):
		failures.append("Neutral flat was not the predictable, straightest tested flat line.")
	if (
		understable_hyzer_apex == null
		or absf(understable_hyzer_apex.bank_degrees) > 7.0
		or absf(understable_hyzer_apex.bank_degrees) >= HYZER_RELEASE_DEGREES
	):
		failures.append("Understable hyzer did not flip close to flat by apex.")
	if understable_flat_apex == null or understable_flat_apex.bank_degrees > -20.0:
		failures.append(
			"Understable flat did not continue into a controlled powered-flight turnover."
		)
	if overstable_hyzer_apex == null or overstable_hyzer_apex.bank_degrees < 20.0:
		failures.append("Overstable disc did not resist powered-flight turn.")
	elif (
		understable_hyzer_apex != null
		and overstable_hyzer_apex.bank_degrees <= understable_hyzer_apex.bank_degrees
	):
		failures.append("Overstable disc did not resist powered-flight turn.")
	if (
		overstable_anhyzer_apex == null
		or absf(overstable_anhyzer_apex.bank_degrees) > UTILITY_MAXIMUM_APEX_ANHYZER_DEGREES
	):
		failures.append("Utility anhyzer did not flex close to flat by apex.")
	if overstable_anhyzer_maximum_x < UTILITY_MINIMUM_FLEX_CLEARANCE_METERS:
		failures.append("Utility anhyzer did not create its minimum right-side flex clearance.")
	if (
		overstable_anhyzer_apex != null
		and overstable_anhyzer_maximum_x_tick <= overstable_anhyzer_apex.tick
	):
		failures.append("Utility anhyzer did not complete its outward curve after apex.")
	if absf(overstable_anhyzer_terminal.position.x) > UTILITY_MAXIMUM_CENTER_FINISH_OFFSET_METERS:
		failures.append("Utility anhyzer did not fade back to the center lane.")
	if overstable_anhyzer_terminal.velocity.x >= 0.0:
		failures.append("Utility anhyzer was not still fading toward center at ground crossing.")
	if not flex_cover_crossing_found:
		failures.append("Utility anhyzer never crossed the visual flex-cover plane.")
	else:
		var flex_cover_clearance := flex_cover_minimum_x - FLEX_COVER_RIGHT_EDGE_X_METERS
		if not flex_cover_crossing_was_powered:
			failures.append("Utility anhyzer reached the flex cover after powered flight.")
		if flex_cover_clearance < FLEX_COVER_MINIMUM_CLEARANCE_METERS:
			failures.append("Utility anhyzer did not clear the right edge of the flex cover.")
		if flex_cover_crossing_position.y >= FLEX_COVER_TOP_Y_METERS:
			failures.append("Utility anhyzer went over the flex cover instead of around it.")

	var no_fade_parameters := (
		DiscParameters
		. new(
			"Overstable without fade",
			disc_parameters[0].turn_tendency,
			disc_parameters[0].turn_resistance,
			0.0,
			disc_parameters[0].color,
		)
	)
	var no_fade_flat := _simulate_to_visual_ground(no_fade_parameters, 0.0)
	var level_release := launch_flight(disc_parameters[1], 0.0, 0.0)
	if level_release.phase != FlightPhase.LATE_FLIGHT or level_release.apex_tick != 0:
		failures.append("A non-rising release did not treat release as its apex.")
	var overstable_apex_index := _apex_index(overstable_flat)
	if overstable_apex_index < 1:
		failures.append("Fade gate comparison never reached an apex.")
	else:
		for state_index in range(overstable_apex_index + 1):
			if not _states_match(overstable_flat[state_index], no_fade_flat[state_index]):
				failures.append("Fade changed state before or on the apex transition tick.")
				break
		var late_sample_index := mini(
			overstable_apex_index + 30,
			mini(overstable_flat.size(), no_fade_flat.size()) - 1,
		)
		if (
			overstable_flat[late_sample_index].bank_degrees
			<= no_fade_flat[late_sample_index].bank_degrees
		):
			failures.append("Fade did not bank the disc after apex.")

	if failures.is_empty():
		verification_landmarks = (
			(
				"neutral flat x %.2f m | understable hyzer apex bank %.1f degrees | "
				+ "understable flat apex bank %.1f degrees | overstable hyzer apex bank %.1f degrees | "
				+ "utility cover clearance %.2f m, max x %.2f m, finish x %.2f m"
			)
			% [
				neutral_terminal.position.x,
				understable_hyzer_apex.bank_degrees,
				understable_flat_apex.bank_degrees,
				overstable_hyzer_apex.bank_degrees,
				flex_cover_minimum_x - FLEX_COVER_RIGHT_EDGE_X_METERS,
				overstable_anhyzer_maximum_x,
				overstable_anhyzer_terminal.position.x,
			]
		)
	return failures


func _verify_trajectory_contract(
	trajectory: Array[FlightState],
	label: String,
	failures: PackedStringArray,
) -> void:
	if trajectory.size() < 2:
		failures.append("%s produced no fixed-step trajectory." % label)
		return
	var transitions := 0
	for state_index in range(trajectory.size()):
		var state: FlightState = trajectory[state_index]
		if (
			not state.position.is_finite()
			or not state.velocity.is_finite()
			or not state.orientation.is_finite()
			or not is_finite(state.bank_degrees)
		):
			failures.append("%s produced non-finite state." % label)
			return
		if state_index == 0:
			continue
		var previous: FlightState = trajectory[state_index - 1]
		if (
			state.tick != previous.tick + 1
			or (
				absf(state.elapsed_seconds - previous.elapsed_seconds - FIXED_TIMESTEP_SECONDS)
				> STATE_TOLERANCE
			)
		):
			failures.append("%s did not advance monotonically by one fixed tick." % label)
			return
		if previous.phase == FlightPhase.POWERED_FLIGHT and state.phase == FlightPhase.LATE_FLIGHT:
			transitions += 1
			if previous.velocity.y <= 0.0 or state.velocity.y > 0.0:
				failures.append(
					"%s transitioned without the rising-to-non-rising velocity crossing." % label
				)
				return
			if (
				(state.position - previous.position).distance_to(
					state.velocity * FIXED_TIMESTEP_SECONDS
				)
				> STATE_TOLERANCE
			):
				failures.append("%s reset or teleported position at apex." % label)
				return
			if (
				state.apex_position.distance_to(state.position) > STATE_TOLERANCE
				or state.apex_velocity.distance_to(state.velocity) > STATE_TOLERANCE
			):
				failures.append("%s did not record the continuous incoming apex state." % label)
				return
			var orientation_step := (
				state.orientation.x.distance_to(previous.orientation.x)
				+ state.orientation.y.distance_to(previous.orientation.y)
				+ state.orientation.z.distance_to(previous.orientation.z)
			)
			var previous_horizontal_speed := (
				Vector2(
					previous.velocity.x,
					previous.velocity.z,
				)
				. length()
			)
			var current_horizontal_speed := (
				Vector2(
					state.velocity.x,
					state.velocity.z,
				)
				. length()
			)
			var vertical_integration_error := absf(
				state.velocity.y - (previous.velocity.y - GRAVITY_MPS2 * FIXED_TIMESTEP_SECONDS)
			)
			var horizontal_speed_error := absf(current_horizontal_speed - previous_horizontal_speed)
			var velocity_step := state.velocity.distance_to(previous.velocity)
			var bank_step := absf(state.bank_degrees - previous.bank_degrees)
			if (
				vertical_integration_error > STATE_TOLERANCE
				or horizontal_speed_error > 0.00001
				or velocity_step > 0.25
				or bank_step > 0.5
				or orientation_step > 0.05
			):
				(
					failures
					. append(
						(
							(
								"%s had a discontinuous apex step: vertical_error=%.6f, "
								+ "horizontal_error=%.6f, velocity=%.4f, bank=%.4f, orientation=%.4f."
							)
							% [
								label,
								vertical_integration_error,
								horizontal_speed_error,
								velocity_step,
								bank_step,
								orientation_step,
							]
						)
					)
				)
	if transitions != 1:
		failures.append(
			"%s produced %d apex transitions instead of exactly one." % [label, transitions]
		)
	var terminal: FlightState = trajectory[trajectory.size() - 1]
	if terminal.phase != FlightPhase.LATE_FLIGHT or terminal.position.y > 0.0:
		failures.append("%s did not reach the visual ground plane in late flight." % label)


func _trajectories_match(first: Array[FlightState], second: Array[FlightState]) -> bool:
	if first.size() != second.size():
		return false
	for state_index in range(first.size()):
		if not _states_match(first[state_index], second[state_index]):
			return false
	return true


func _states_match(first: FlightState, second: FlightState) -> bool:
	return (
		first.phase == second.phase
		and first.tick == second.tick
		and first.apex_tick == second.apex_tick
		and first.position.distance_to(second.position) <= STATE_TOLERANCE
		and first.velocity.distance_to(second.velocity) <= STATE_TOLERANCE
		and absf(first.bank_degrees - second.bank_degrees) <= STATE_TOLERANCE
		and first.orientation.x.distance_to(second.orientation.x) <= STATE_TOLERANCE
		and first.orientation.y.distance_to(second.orientation.y) <= STATE_TOLERANCE
		and first.orientation.z.distance_to(second.orientation.z) <= STATE_TOLERANCE
	)


func _apex_index(trajectory: Array[FlightState]) -> int:
	for state_index in range(1, trajectory.size()):
		var previous: FlightState = trajectory[state_index - 1]
		var state: FlightState = trajectory[state_index]
		if previous.phase == FlightPhase.POWERED_FLIGHT and state.phase == FlightPhase.LATE_FLIGHT:
			return state_index
	return -1


func _apex_state(trajectory: Array[FlightState]) -> FlightState:
	var state_index := _apex_index(trajectory)
	return trajectory[state_index] if state_index >= 0 else null
