extends Node3D

## Fixed-command visual harness for the pure arcade airborne simulator.
##
## This lab presents explicit arcade state only. It does not query collisions,
## collect player input, or define projectile lifecycle rules.

@export var flight_profile: ArcadeFlightProfile
@export var available_flight_profiles: Array[ArcadeFlightProfile] = []

@onready var release_point: Marker3D = $ReleasePoint
@onready var disc_visual: MeshInstance3D = $DiscVisual
@onready var overview_camera: Camera3D = $OverviewCamera
@onready var player: Node = $Player
@onready var status_label: Label = $UI/StatusPanel/StatusLabel
@onready var profile_select: OptionButton = $UI/ControlsPanel/Controls/ProfileSelect
@onready var throw_button: Button = $UI/ControlsPanel/Controls/ThrowButton
@onready var reset_button: Button = $UI/ControlsPanel/Controls/ResetButton

var simulator := ArcadeFlightSimulator.new()
var flight_environment := ArcadeFlightEnvironment.new()
var flight_state: ArcadeFlightState
var simulation_time_accumulator := 0.0
var has_landed := false


func _ready() -> void:
	profile_select.clear()
	for profile in available_flight_profiles:
		if profile != null:
			profile_select.add_item(profile.resource_name)
	var selected_index := available_flight_profiles.find(flight_profile)
	if selected_index >= 0:
		profile_select.select(selected_index)
	if flight_profile == null:
		push_error("Arcade Flight Lab requires an ArcadeFlightProfile.")
		profile_select.disabled = true
		throw_button.disabled = true
		reset_button.disabled = true
		return
	var validation_errors := flight_profile.validate()
	if not validation_errors.is_empty():
		push_error("Arcade Flight Lab rejected invalid profile: %s" % ", ".join(validation_errors))
		profile_select.disabled = true
		throw_button.disabled = true
		reset_button.disabled = true
		return
	player.connect("arcade_throw_requested", _on_player_arcade_throw_requested)
	_on_reset_button_pressed()


func _physics_process(delta: float) -> void:
	if flight_state == null \
		or has_landed \
		or flight_state.lifecycle != ArcadeFlightState.Lifecycle.FLYING:
		return
	simulation_time_accumulator += delta
	var presentation_position := flight_state.position
	while simulation_time_accumulator >= ArcadeFlightSimulator.FIXED_TIMESTEP_SECONDS \
		and flight_state.lifecycle == ArcadeFlightState.Lifecycle.FLYING \
		and not has_landed:
		var previous_position := flight_state.position
		flight_state = simulator.step(
			flight_state,
			flight_profile,
			ArcadeFlightSimulator.FIXED_TIMESTEP_SECONDS,
			flight_environment,
		)
		simulation_time_accumulator -= ArcadeFlightSimulator.FIXED_TIMESTEP_SECONDS
		if previous_position.y > 0.0 and flight_state.position.y <= 0.0:
			var ground_crossing_fraction := previous_position.y / (
				previous_position.y - flight_state.position.y
			)
			presentation_position = previous_position.lerp(
				flight_state.position,
				ground_crossing_fraction,
			)
			has_landed = true
	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		presentation_position,
	)
	overview_camera.global_position = disc_visual.global_position + Vector3(0.0, 1.2, 3.5)
	overview_camera.look_at(disc_visual.global_position, Vector3.UP)
	if has_landed:
		status_label.text = "%s — visual ground crossing at %.1f m" % [
			flight_profile.resource_name,
			flight_state.travel_distance_meters,
		]
		return
	status_label.text = "%s — %.1f m traveled, tick %d" % [
		flight_profile.resource_name,
		flight_state.travel_distance_meters,
		flight_state.tick,
	]


func _on_throw_button_pressed() -> void:
	if flight_state != null \
		and flight_state.lifecycle == ArcadeFlightState.Lifecycle.FLYING \
		and not has_landed:
		return
	var command := ArcadeThrowCommand.new(
		release_point.global_position,
		Vector3.FORWARD,
		1.0,
		0.0,
		8.0,
		ArcadeThrowCommand.SpinDirection.NATURAL_FINISH_RIGHT,
	)
	flight_state = simulator.launch(command, flight_profile)
	simulation_time_accumulator = 0.0
	has_landed = false
	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		flight_state.position,
	)
	status_label.text = "%s — fixed full-charge, 8° uphill release" % flight_profile.resource_name


func _on_player_arcade_throw_requested(command: ArcadeThrowCommand) -> void:
	if flight_state != null \
		and flight_state.lifecycle == ArcadeFlightState.Lifecycle.FLYING \
		and not has_landed:
		return
	flight_state = simulator.launch(command, flight_profile)
	simulation_time_accumulator = 0.0
	has_landed = false
	disc_visual.global_transform = Transform3D(
		flight_state.orientation,
		flight_state.position,
	)
	status_label.text = "%s — player release at %d%% charge" % [
		flight_profile.resource_name,
		roundi(command.charge * 100.0),
	]


func _on_reset_button_pressed() -> void:
	flight_state = null
	simulation_time_accumulator = 0.0
	has_landed = false
	disc_visual.global_transform = Transform3D(Basis.IDENTITY, release_point.global_position)
	overview_camera.global_position = disc_visual.global_position + Vector3(0.0, 1.2, 3.5)
	overview_camera.look_at(disc_visual.global_position, Vector3.UP)
	status_label.text = "%s — ready" % flight_profile.resource_name


func _on_profile_select_item_selected(index: int) -> void:
	if flight_state != null \
		and flight_state.lifecycle == ArcadeFlightState.Lifecycle.FLYING \
		and not has_landed:
		profile_select.select(available_flight_profiles.find(flight_profile))
		return
	if index < 0 or index >= available_flight_profiles.size():
		return
	var selected_profile: ArcadeFlightProfile = available_flight_profiles[index]
	if selected_profile == null:
		return
	var validation_errors := selected_profile.validate()
	if not validation_errors.is_empty():
		push_error("Arcade Flight Lab rejected invalid profile: %s" % ", ".join(validation_errors))
		profile_select.select(available_flight_profiles.find(flight_profile))
		return
	flight_profile = selected_profile
	_on_reset_button_pressed()
