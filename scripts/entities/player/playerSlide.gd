extends Resource
class_name PlayerSlide

# Slide Settings
@export var slide_duration: float = 1.0
@export var slide_friction: float = 5.0
@export var min_slide_speed: float = 2.0
@export var slide_angle_threshold: float = 30.0

# Slide variables
var slide_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var is_sliding: bool = false

var player: CharacterBody3D

signal slide_started()
signal slide_ended()

func _init(player_ref: CharacterBody3D):
	player = player_ref

func start_slide(movement_direction: Vector3):
	slide_timer = slide_duration
	slide_direction = movement_direction if movement_direction.length() > 0 else -player.transform.basis.z
	is_sliding = true
	slide_started.emit()

func end_slide():
	is_sliding = false
	slide_ended.emit()

func update_slide(delta: float, slide_speed: float) -> Vector3:
	slide_timer -= delta
	
	# Maintain slide direction and apply friction
	var slide_vel = slide_direction * slide_speed
	slide_vel = slide_vel.move_toward(Vector3.ZERO, slide_friction * delta)
	
	return slide_vel

func should_end_slide() -> bool:
	return slide_timer <= 0 or player.velocity.length() < min_slide_speed or not Input.is_action_pressed("crouch")

func can_start_slide(current_velocity: Vector3) -> bool:
	return current_velocity.length() > min_slide_speed
