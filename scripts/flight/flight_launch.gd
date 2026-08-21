class_name FlightLaunch
extends RefCounted


static func create_state(
	release_position: Vector3,
	release_basis: Basis,
	throw: ThrowParameters,
) -> FlightState:
	var launch_angle := deg_to_rad(throw.launch_angle)
	var nose_angle := deg_to_rad(throw.nose_angle)
	var release_angle := deg_to_rad(throw.release_angle)
	var aim_basis := release_basis.orthonormalized()
	var launch_direction := aim_basis * Vector3(
		0.0,
		sin(launch_angle),
		-cos(launch_angle),
	)
	launch_direction = launch_direction.normalized()

	# At zero nose angle, the disc normal is perpendicular to the intended
	# flight path. This prevents launch, nose, and hyzer from being coupled by
	# Godot's Euler-angle composition.
	var reference_up := aim_basis.y.normalized()
	var disc_normal := reference_up - (
		launch_direction * reference_up.dot(launch_direction)
	)
	disc_normal = disc_normal.normalized()

	var right_axis := launch_direction.cross(disc_normal).normalized()
	disc_normal = disc_normal.rotated(right_axis, nose_angle)
	# Positive release angle retains the existing lab convention: hyzer tilts
	# the disc normal toward the thrower's left on a forward (-Z) throw.
	disc_normal = disc_normal.rotated(launch_direction, -release_angle)

	right_axis = launch_direction.cross(disc_normal).normalized()
	var orientation := Basis(right_axis, disc_normal, -launch_direction)

	return FlightState.new(
		release_position,
		launch_direction * throw.speed,
		throw.spin_rate,
		orientation,
	)
