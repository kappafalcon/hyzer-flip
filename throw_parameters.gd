class_name ThrowParameters
extends RefCounted


var speed: float
var spin_rate: float
var release_angle: float
var launch_angle: float


func _init(
	initial_speed: float,
	initial_spin_rate: float,
	initial_release_angle: float,
	initial_launch_angle: float
):
	speed = initial_speed
	spin_rate = initial_spin_rate
	release_angle = initial_release_angle
	launch_angle = initial_launch_angle
