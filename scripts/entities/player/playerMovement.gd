extends Resource
class_name PlayerMovement

# Movement Settings
@export var walk_speed: float = 3.0
@export var run_speed: float = 6.0
@export var crouch_speed: float = 1.5
@export var slide_speed: float = 8.0
@export var acceleration: float = 10.0
@export var deceleration: float = 15.0
@export var air_acceleration: float = 5.0

# Physics Settings
@export var gravity_multiplier: float = 1.0
@export var fall_gravity_multiplier: float = 1.5
@export var max_fall_speed: float = 20.0

# Rotation Settings
@export var rotation_speed: float = 10.0 

var player: CharacterBody3D
var input_direction: Vector2 = Vector2.ZERO
var movement_direction: Vector3 = Vector3.ZERO
var target_velocity: Vector3 = Vector3.ZERO
var current_speed: float = 0.0

func _init(player_ref: CharacterBody3D):
	player = player_ref

func get_input():
	input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement_direction = Vector3(input_direction.x, 0, input_direction.y).normalized()

func set_target_velocity(speed: float):
	current_speed = speed
	target_velocity = movement_direction * current_speed

func apply_movement(delta: float):
	# Karakter rotasyonu (hareket yönüne doğru döndür)
	if movement_direction != Vector3.ZERO and player.is_on_floor():
		var target_rotation = atan2(movement_direction.x, movement_direction.z)
		player.rotation.y = lerp_angle(player.rotation.y, target_rotation, rotation_speed * delta)
	
	# Apply gravity
	if not player.is_on_floor():
		var gravity_mult = fall_gravity_multiplier if player.velocity.y < 0 else gravity_multiplier
		player.velocity += player.get_gravity() * gravity_mult * delta
		player.velocity.y = max(player.velocity.y, -max_fall_speed)
	
	# Apply horizontal movement
	var accel = acceleration if player.is_on_floor() else air_acceleration
	
	if target_velocity.length() > 0:
		player.velocity.x = move_toward(player.velocity.x, target_velocity.x, accel * delta)
		player.velocity.z = move_toward(player.velocity.z, target_velocity.z, accel * delta)
	else:
		var decel = deceleration if player.is_on_floor() else air_acceleration * 0.5
		player.velocity.x = move_toward(player.velocity.x, 0, decel * delta)
		player.velocity.z = move_toward(player.velocity.z, 0, decel * delta)

func get_horizontal_velocity() -> Vector3:
	return Vector3(player.velocity.x, 0, player.velocity.z)

func get_movement_speed() -> float:
	return get_horizontal_velocity().length()

func is_moving() -> bool:
	return player.velocity.length() > 0.1
