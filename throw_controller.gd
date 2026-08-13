extends Node
@onready var disc = $"../Disc"
@onready var release_point = $"../PlayerOrigin/ReleasePoint"

var release_angle: float = 0.0

const MIN_RELEASE_ANGLE: float = -30.0
const MAX_RELEASE_ANGLE: float = 30.0
const ANGLE_STEP: float = 10.0


# Initializes disc location on scene load
func _ready():
	disc.global_position = release_point.global_position
	
	
# Input scanner/controller
func _process(_delta):
	if Input.is_action_just_pressed("release_hyzer"):
		change_release_angle(ANGLE_STEP)

	if Input.is_action_just_pressed("release_anhyzer"):
		change_release_angle(-ANGLE_STEP)
		
	if Input.is_action_just_pressed("throw_disc"):
		throw_disc()


func change_release_angle(amount: float):
	release_angle = clamp(
		release_angle + amount,
		MIN_RELEASE_ANGLE,
		MAX_RELEASE_ANGLE
	)
	
	print("Release angle: ", release_angle)
	
	
func throw_disc():
	# Need to update how much "power" the throw is given with user input e.g. holding left click
	var initial_velocity = Vector3(0, 0, -20)
	var initial_spin_rate = 60.0
	
	disc.launch(
		release_point.global_position,
		initial_velocity,
		initial_spin_rate,
		release_angle
	)
