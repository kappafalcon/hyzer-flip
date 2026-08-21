class_name FlightEnvironment
extends RefCounted

# Air movement in world-space metres per second. Keeping it in a standalone
# value object lets every aerodynamic calculation share the same environment
# without making scenes or controls authoritative over the flight model.
var wind_velocity: Vector3


func _init(initial_wind_velocity: Vector3 = Vector3.ZERO) -> void:
	wind_velocity = initial_wind_velocity


func get_air_velocity(disc_velocity: Vector3) -> Vector3:
	return disc_velocity - wind_velocity
