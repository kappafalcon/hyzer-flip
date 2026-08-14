extends Node3D


@onready var disc = $Disc
@onready var release_point = $ReleasePoint

@onready var speed_input = $UI/Panel/Controls/SpeedInput
@onready var spin_input = $UI/Panel/Controls/SpinInput
@onready var release_angle_input = $UI/Panel/Controls/ReleaseAngleInput
@onready var launch_angle_input = $UI/Panel/Controls/LaunchAngleInput


func _on_throw_button_pressed() -> void:
	var throw = ThrowParameters.new(
		speed_input.value,
		spin_input.value,
		release_angle_input.value,
		launch_angle_input.value
	)

	disc.launch(
		release_point.global_position,
		throw
	)


func _on_reset_button_pressed() -> void:
	disc.reset(release_point.global_position)
