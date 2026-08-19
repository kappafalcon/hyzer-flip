class_name ThrowParameters
extends RefCounted

var speed: float
var spin_rate: float
var release_angle: float
var launch_angle: float
var nose_angle: float


func _init(
	initial_speed_mph: float,
	initial_spin_rpm: float,
	initial_release_angle: float,
	initial_launch_angle: float,
	initial_nose_angle: float
):
	speed = mph_to_mps(initial_speed_mph)
	spin_rate = rpm_to_rad_per_second(initial_spin_rpm)
	release_angle = initial_release_angle
	launch_angle = initial_launch_angle
	nose_angle = initial_nose_angle


static func mph_to_mps(mph: float) -> float:
	return mph * 0.44704


static func rpm_to_rad_per_second(rpm: float) -> float:
	return rpm * TAU / 60.0
