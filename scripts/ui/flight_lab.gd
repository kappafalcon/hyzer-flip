extends Node3D

@onready var disc = $Disc
@onready var release_point = $ReleasePoint

@export var throw_speed: float = 25.0
@export var throw_spin: float = 900.0
@export var throw_release_angle: float = 0.0
@export var throw_launch_angle: float = 5.0
@export var throw_nose_angle: float = 0.0

func _on_throw_button_pressed() -> void:

	var throw = ThrowParameters.new(
		throw_speed,
		throw_spin,
		throw_release_angle,
		throw_launch_angle,
		throw_nose_angle
	)

	disc.launch(release_point.global_transform, throw)


func _on_reset_button_pressed() -> void:
	disc.reset(release_point.global_transform)
