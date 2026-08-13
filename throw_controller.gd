extends Node
@onready var disc = $"../Disc"
@onready var release_point = $"../PlayerOrigin/ReleasePoint"

var release_angle: float = 0.0

const MIN_RELEASE_ANGLE: float = -30.0
const MAX_RELEASE_ANGLE: float = 30.0
const ANGLE_STEP: float = 10.0


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
	var initial_velocity = Vector3(0, 0, -10)

	disc.launch(
		release_point.global_position,
		initial_velocity,
		release_angle
	)

func _ready():
	disc.global_position = release_point.global_position

	print("Release point: ", release_point.global_position)
	print("Disc: ", disc.global_position)
