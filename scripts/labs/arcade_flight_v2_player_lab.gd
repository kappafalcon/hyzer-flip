extends Node3D

## Player-command adapter and presentation driver for the isolated flight-model-v2 prototype.
##
## The reusable Player owns input and emits an immutable ArcadeThrowCommand.
## This lab converts charge to launch speed once, advances the pure prototype at
## 120 Hz, and projects its state onto a visual disc. The current arcade flight
## simulator, collision physics, and main scene are deliberately not involved.

const FlightPrototype = preload("res://scripts/flight/arcade/arcade_flight_prototype.gd")

const MINIMUM_CHARGE_SPEED_MULTIPLIER := 0.775
const MAXIMUM_CHARGE_SPEED_MULTIPLIER := 1.225
# Presentation-only: the same fixed solver ticks are projected 100% faster.
const PRESENTATION_TIME_SCALE := 2
const VERIFICATION_TOLERANCE := 0.000001
const SPEED_TOLERANCE := 0.0001
const MAXIMUM_VERIFICATION_TICKS := 600
const PREVIEW_TRACE_INTERVAL_TICKS := 2
const POWERED_FLIGHT_PREVIEW_COLOR := Color(0.16, 0.48, 1.0, 0.92)
const APEX_PREVIEW_COLOR := Color(1.0, 0.84, 0.12, 0.96)
const EARLY_FADE_PREVIEW_COLOR := Color(1.0, 0.43, 0.08, 0.96)
const LATE_FLIGHT_PREVIEW_COLOR := Color(1.0, 0.16, 0.12, 0.96)
const APEX_TO_ORANGE_SECONDS := 0.20
const ORANGE_TO_RED_SECONDS := 0.65

var disc_parameters: Array[FlightPrototype.DiscParameters] = []
var active_parameters: FlightPrototype.DiscParameters
var flight_state: FlightPrototype.FlightState
var selected_parameters_index := 0
var simulation_time_accumulator := 0.0
var has_landed := true
var presentation_position := Vector3.ZERO
var launch_origin := Vector3.ZERO
var preview_mesh := ImmediateMesh.new()
var preview_visual := MeshInstance3D.new()
var preview_half_width := 0.21

@onready var release_point: Marker3D = $ReleasePoint
@onready var disc_visual: MeshInstance3D = $DiscVisual
@onready var player: Node = $Player
@onready var status_label: Label = $UI/StatusPanel/StatusLabel


func _ready() -> void:
	disc_parameters = FlightPrototype.create_default_disc_parameters()
	active_parameters = disc_parameters[selected_parameters_index]
	player.connect(&"arcade_throw_requested", _on_player_arcade_throw_requested)
	player.connect(&"arcade_throw_preview_requested", _on_player_arcade_throw_preview_requested)
	player.connect(&"arcade_throw_preview_cleared", _clear_throw_preview)
	preview_visual.mesh = preview_mesh
	preview_visual.material_override = _create_preview_material()
	preview_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	preview_visual.visible = false
	add_child(preview_visual)
	disc_visual.visible = false
	var disc_mesh := disc_visual.mesh as CylinderMesh
	if disc_mesh != null:
		preview_half_width = disc_mesh.top_radius

	if DisplayServer.get_name() == "headless":
		var verification_failures := _run_headless_adapter_verification()
		if verification_failures.is_empty():
			print(
				(
					"ARCADE_FLIGHT_V2_PLAYER_TEST PASS "
					+ "player signal | arbitrary origin/heading | "
					+ "17.05-26.95 m/s charge | identical replay"
				)
			)
			get_tree().quit(0)
		else:
			for failure in verification_failures:
				push_error("ARCADE_FLIGHT_V2_PLAYER_TEST: %s" % failure)
			get_tree().quit(1)
		return

	_on_reset_button_pressed()


func _unhandled_input(event: InputEvent) -> void:
	var requested_index := -1
	if event.is_action_pressed("select_utility_driver"):
		requested_index = 0
	elif event.is_action_pressed("select_neutral_mid"):
		requested_index = 1
	elif event.is_action_pressed("select_beat_in_driver"):
		requested_index = 2
	else:
		return

	if _is_airborne():
		return
	selected_parameters_index = requested_index
	_on_reset_button_pressed()
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not _is_airborne():
		return
	simulation_time_accumulator += delta * PRESENTATION_TIME_SCALE
	while simulation_time_accumulator >= FlightPrototype.FIXED_TIMESTEP_SECONDS:
		var previous_state := flight_state
		flight_state = (
			FlightPrototype
			. step_flight(
				previous_state,
				active_parameters,
				FlightPrototype.FIXED_TIMESTEP_SECONDS,
			)
		)
		simulation_time_accumulator -= FlightPrototype.FIXED_TIMESTEP_SECONDS
		presentation_position = flight_state.position
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
			has_landed = true
			break

	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		presentation_position,
	)
	if has_landed:
		status_label.text = (
			"%s — ground at %.1f m, tick %d"
			% [
				active_parameters.display_name,
				_horizontal_distance_from_launch(),
				flight_state.tick,
			]
		)
		return
	var phase_name := "POWERED_FLIGHT"
	if flight_state.phase == FlightPrototype.FlightPhase.LATE_FLIGHT:
		phase_name = "LATE_FLIGHT"
	status_label.text = (
		"%s — %s, bank %.1f°, tick %d"
		% [
			active_parameters.display_name,
			phase_name,
			flight_state.bank_degrees,
			flight_state.tick,
		]
	)


func _on_throw_button_pressed() -> void:
	var command := (
		ArcadeThrowCommand
		. new(
			release_point.global_position,
			Vector3.FORWARD,
			1.0,
			-22.0,
			FlightPrototype.LAUNCH_PITCH_DEGREES,
			ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
		)
	)
	_launch_command(command)


func _on_player_arcade_throw_requested(command: ArcadeThrowCommand) -> void:
	_launch_command(command)


func _on_player_arcade_throw_preview_requested(command: ArcadeThrowCommand) -> void:
	if _is_airborne() or command == null or not command.is_valid():
		return
	_draw_throw_preview(command, disc_parameters[selected_parameters_index])


func _launch_command(command: ArcadeThrowCommand) -> void:
	if _is_airborne():
		return
	if command == null or not command.is_valid():
		push_error("Flight v2 player lab rejected an invalid throw command.")
		return
	if command.fade_direction != ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT:
		push_error("Flight v2 player lab currently supports natural-left finishes only.")
		return

	active_parameters = disc_parameters[selected_parameters_index]
	flight_state = _create_launch_state(command, active_parameters)
	launch_origin = command.origin
	presentation_position = flight_state.position
	simulation_time_accumulator = 0.0
	has_landed = false
	disc_visual.visible = true
	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		flight_state.position,
	)
	_clear_throw_preview()
	status_label.text = (
		"%s — player release at %d%% charge"
		% [
			active_parameters.display_name,
			roundi(command.charge * 100.0),
		]
	)


func _on_reset_button_pressed() -> void:
	active_parameters = disc_parameters[selected_parameters_index]
	flight_state = null
	simulation_time_accumulator = 0.0
	has_landed = true
	presentation_position = release_point.global_position
	launch_origin = presentation_position
	disc_visual.visible = false
	disc_visual.global_transform = Transform3D(Basis.IDENTITY, presentation_position)
	_clear_throw_preview()
	status_label.text = "%s — ready (Q/E bank, 1/2/3 disc)" % active_parameters.display_name


func _create_launch_state(
	command: ArcadeThrowCommand,
	parameters: FlightPrototype.DiscParameters,
) -> FlightPrototype.FlightState:
	return (
		FlightPrototype
		. launch_flight(
			parameters,
			command.release_bank_degrees,
			command.launch_pitch_degrees,
			command.origin,
			command.horizontal_forward,
			_launch_speed_for_charge(command.charge),
		)
	)


func _launch_speed_for_charge(charge: float) -> float:
	var speed_multiplier := lerpf(
		MINIMUM_CHARGE_SPEED_MULTIPLIER,
		MAXIMUM_CHARGE_SPEED_MULTIPLIER,
		clampf(charge, 0.0, 1.0),
	)
	return FlightPrototype.LAUNCH_SPEED_MPS * speed_multiplier


func _horizontal_distance_from_launch() -> float:
	return (
		Vector2(
			presentation_position.x - launch_origin.x,
			presentation_position.z - launch_origin.z,
		)
		. length()
	)


func _is_airborne() -> bool:
	return flight_state != null and not has_landed


func _draw_throw_preview(
	command: ArcadeThrowCommand,
	parameters: FlightPrototype.DiscParameters,
) -> void:
	var state := _create_launch_state(command, parameters)
	var preview_points: Array[Vector3] = [state.position]
	var preview_colors: Array[Color] = [POWERED_FLIGHT_PREVIEW_COLOR]
	var preview_roll_axes: Array[Vector3] = [state.orientation.x]
	for _tick in range(MAXIMUM_VERIFICATION_TICKS):
		var next_state := (
			FlightPrototype
			. step_flight(
				state,
				parameters,
				FlightPrototype.FIXED_TIMESTEP_SECONDS,
			)
		)
		if state.position.y > 0.0 and next_state.position.y <= 0.0:
			var ground_fraction := state.position.y / (state.position.y - next_state.position.y)
			preview_points.append(state.position.lerp(next_state.position, ground_fraction))
			preview_colors.append(_preview_color_for_state(next_state, false))
			preview_roll_axes.append(next_state.orientation.x)
			break
		var is_apex_transition := (
			state.phase == FlightPrototype.FlightPhase.POWERED_FLIGHT
			and next_state.phase == FlightPrototype.FlightPhase.LATE_FLIGHT
		)
		if is_apex_transition or next_state.tick % PREVIEW_TRACE_INTERVAL_TICKS == 0:
			preview_points.append(next_state.position)
			preview_colors.append(_preview_color_for_state(next_state, is_apex_transition))
			preview_roll_axes.append(next_state.orientation.x)
		state = next_state
	preview_mesh.clear_surfaces()
	preview_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point_index in range(preview_points.size() - 1):
		var start := preview_points[point_index]
		var end := preview_points[point_index + 1]
		var start_side := preview_roll_axes[point_index]
		var end_side := preview_roll_axes[point_index + 1]
		if start_side.length_squared() <= 0.000001:
			start_side = Vector3.RIGHT
		if end_side.length_squared() <= 0.000001:
			end_side = Vector3.RIGHT
		start_side = start_side.normalized() * preview_half_width
		end_side = end_side.normalized() * preview_half_width
		var start_left := start - start_side
		var start_right := start + start_side
		var end_left := end - end_side
		var end_right := end + end_side
		preview_mesh.surface_set_color(preview_colors[point_index])
		preview_mesh.surface_add_vertex(start_left)
		preview_mesh.surface_add_vertex(start_right)
		preview_mesh.surface_set_color(preview_colors[point_index + 1])
		preview_mesh.surface_add_vertex(end_right)
		preview_mesh.surface_set_color(preview_colors[point_index])
		preview_mesh.surface_add_vertex(start_left)
		preview_mesh.surface_set_color(preview_colors[point_index + 1])
		preview_mesh.surface_add_vertex(end_right)
		preview_mesh.surface_add_vertex(end_left)
	preview_mesh.surface_end()
	preview_visual.visible = true


func _clear_throw_preview() -> void:
	preview_mesh.clear_surfaces()
	preview_visual.visible = false


func _create_preview_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _preview_color_for_state(
	state: FlightPrototype.FlightState,
	is_apex_transition: bool,
) -> Color:
	if is_apex_transition:
		return APEX_PREVIEW_COLOR
	if state.phase == FlightPrototype.FlightPhase.LATE_FLIGHT:
		var fade_elapsed_seconds := maxf(
			(state.tick - state.apex_tick) * FlightPrototype.FIXED_TIMESTEP_SECONDS,
			0.0,
		)
		if fade_elapsed_seconds <= APEX_TO_ORANGE_SECONDS:
			return APEX_PREVIEW_COLOR.lerp(
				EARLY_FADE_PREVIEW_COLOR,
				fade_elapsed_seconds / APEX_TO_ORANGE_SECONDS,
			)
		return EARLY_FADE_PREVIEW_COLOR.lerp(
			LATE_FLIGHT_PREVIEW_COLOR,
			clampf(
				(fade_elapsed_seconds - APEX_TO_ORANGE_SECONDS) / ORANGE_TO_RED_SECONDS,
				0.0,
				1.0,
			),
		)
	return POWERED_FLIGHT_PREVIEW_COLOR


func _run_headless_adapter_verification() -> PackedStringArray:
	var failures := PackedStringArray()
	var expected_origin := Vector3(3.0, 2.5, 4.0)
	var expected_heading := Vector3(1.0, 0.0, -1.0).normalized()
	var player_pitch_offset := float(player.get("launch_pitch_offset_degrees"))
	if absf(player_pitch_offset) > VERIFICATION_TOLERANCE:
		failures.append("Player lab added a launch-pitch offset instead of tracing the reticle.")
	var full_charge_command := (
		ArcadeThrowCommand
		. new(
			expected_origin,
			expected_heading,
			1.0,
			-22.0,
			15.0,
			ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
		)
	)
	var first := _create_launch_state(full_charge_command, disc_parameters[0])
	var second := _create_launch_state(full_charge_command, disc_parameters[0])
	var horizontal_velocity := Vector3(first.velocity.x, 0.0, first.velocity.z).normalized()
	var expected_camera_ray := (
		(
			expected_heading * cos(deg_to_rad(full_charge_command.launch_pitch_degrees))
			+ Vector3.UP * sin(deg_to_rad(full_charge_command.launch_pitch_degrees))
		)
		. normalized()
	)
	if first.position.distance_to(expected_origin) > VERIFICATION_TOLERANCE:
		failures.append("Command origin did not reach the v2 launch state.")
	if horizontal_velocity.distance_to(expected_heading) > VERIFICATION_TOLERANCE:
		failures.append("Command heading did not reach the v2 launch state.")
	if first.velocity.normalized().distance_to(expected_camera_ray) > VERIFICATION_TOLERANCE:
		failures.append("V2 launch velocity did not trace the captured camera ray.")
	var expected_full_charge_speed := (
		FlightPrototype.LAUNCH_SPEED_MPS * MAXIMUM_CHARGE_SPEED_MULTIPLIER
	)
	if absf(first.velocity.length() - expected_full_charge_speed) > SPEED_TOLERANCE:
		failures.append(
			"Full charge speed %.4f m/s did not match %.4f m/s."
			% [first.velocity.length(), expected_full_charge_speed]
		)
	if absf(first.bank_degrees - full_charge_command.release_bank_degrees) > VERIFICATION_TOLERANCE:
		failures.append("Command release bank did not reach the v2 launch state.")
	if not first.orientation.is_finite() or absf(first.orientation.determinant() - 1.0) > 0.00001:
		failures.append("Player-driven launch orientation was not finite and orthonormal.")
	player.emit_signal(&"arcade_throw_preview_requested", full_charge_command)
	if not preview_visual.visible or preview_mesh.get_surface_count() != 1:
		failures.append("Player preview signal did not create a local trajectory line.")
	var preview_vertices: PackedVector3Array = preview_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	if (
		preview_vertices.size() < 6
		or absf(preview_vertices[0].distance_to(expected_origin) - preview_half_width)
		> VERIFICATION_TOLERANCE
	):
		failures.append("Player preview ribbon did not begin at the captured throw origin.")
	elif absf(preview_vertices[0].y - expected_origin.y) <= 0.01:
		failures.append("Player preview ribbon did not inherit the commanded disc roll.")

	var minimum_charge_command := (
		ArcadeThrowCommand
		. new(
			expected_origin,
			expected_heading,
			0.0,
			0.0,
			15.0,
			ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
		)
	)
	var minimum_charge_state := _create_launch_state(minimum_charge_command, disc_parameters[1])
	var expected_minimum_speed := FlightPrototype.LAUNCH_SPEED_MPS * MINIMUM_CHARGE_SPEED_MULTIPLIER
	if (
		absf(minimum_charge_state.velocity.length() - expected_minimum_speed)
		> SPEED_TOLERANCE
	):
		failures.append(
			"Minimum charge speed %.4f m/s did not match %.4f m/s."
			% [minimum_charge_state.velocity.length(), expected_minimum_speed]
		)
	var midpoint_charge_command := (
		ArcadeThrowCommand
		. new(
			expected_origin,
			expected_heading,
			0.5,
			0.0,
			15.0,
			ArcadeThrowCommand.FadeDirection.NATURAL_FINISH_LEFT,
		)
	)
	var midpoint_charge_state := _create_launch_state(midpoint_charge_command, disc_parameters[1])
	if absf(midpoint_charge_state.velocity.length() - FlightPrototype.LAUNCH_SPEED_MPS) > SPEED_TOLERANCE:
		failures.append("Half charge did not preserve the former full-charge launch speed.")

	var reached_ground := false
	for _tick in range(MAXIMUM_VERIFICATION_TICKS):
		if not _prototype_states_match(first, second):
			failures.append(
				"Identical player commands did not reproduce the same v2 state sequence."
			)
			break
		if first.phase == FlightPrototype.FlightPhase.LATE_FLIGHT and first.position.y <= 0.0:
			reached_ground = true
			break
		first = (
			FlightPrototype
			. step_flight(
				first,
				disc_parameters[0],
				FlightPrototype.FIXED_TIMESTEP_SECONDS,
			)
		)
		second = (
			FlightPrototype
			. step_flight(
				second,
				disc_parameters[0],
				FlightPrototype.FIXED_TIMESTEP_SECONDS,
			)
		)
	if not reached_ground:
		failures.append("Player-driven v2 verification did not reach visual ground.")
	player.emit_signal(&"arcade_throw_requested", full_charge_command)
	if (
		flight_state == null
		or flight_state.position.distance_to(expected_origin) > VERIFICATION_TOLERANCE
	):
		failures.append("Player throw signal did not launch the v2 presentation state.")
	if preview_visual.visible:
		failures.append("Player throw did not clear the local trajectory preview.")
	return failures


func _prototype_states_match(
	first: FlightPrototype.FlightState,
	second: FlightPrototype.FlightState,
) -> bool:
	return (
		first.phase == second.phase
		and first.tick == second.tick
		and first.apex_tick == second.apex_tick
		and first.position.distance_to(second.position) <= VERIFICATION_TOLERANCE
		and first.velocity.distance_to(second.velocity) <= VERIFICATION_TOLERANCE
		and absf(first.bank_degrees - second.bank_degrees) <= VERIFICATION_TOLERANCE
		and absf(first.release_bank_degrees - second.release_bank_degrees) <= VERIFICATION_TOLERANCE
		and absf(first.launch_pitch_degrees - second.launch_pitch_degrees) <= VERIFICATION_TOLERANCE
		and first.orientation.x.distance_to(second.orientation.x) <= VERIFICATION_TOLERANCE
		and first.orientation.y.distance_to(second.orientation.y) <= VERIFICATION_TOLERANCE
		and first.orientation.z.distance_to(second.orientation.z) <= VERIFICATION_TOLERANCE
	)
