extends Resource
class_name PlayerJump

# Jump Settings
@export var jump_velocity: float = 8.0
@export var double_jump_velocity: float = 6.0
@export var max_jumps: int = 2
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.2

# Jump variables
var jumps_remaining: int = 0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false

var player: CharacterBody3D

signal jumped()

func _init(player_ref: CharacterBody3D):
	player = player_ref
	jumps_remaining = max_jumps

func get_input():
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time

func update_timers(delta: float):
	# Coyote time
	if was_on_floor and not player.is_on_floor():
		coyote_timer = coyote_time
	elif player.is_on_floor():
		coyote_timer = 0.0
	else:
		coyote_timer -= delta
	
	# Jump buffer
	jump_buffer_timer = max(0, jump_buffer_timer - delta)

func post_movement_update():
	# Update jump state
	if player.is_on_floor() and not was_on_floor:
		jumps_remaining = max_jumps
	
	was_on_floor = player.is_on_floor()

func can_jump() -> bool:
	return (player.is_on_floor() or coyote_timer > 0) or jumps_remaining > 0

func perform_jump():
	if player.is_on_floor() or coyote_timer > 0:
		player.velocity.y = jump_velocity
		jumps_remaining = max_jumps - 1
	else:
		player.velocity.y = double_jump_velocity
		jumps_remaining -= 1
	
	jump_buffer_timer = 0
	coyote_timer = 0
	jumped.emit()

func has_jump_input() -> bool:
	return jump_buffer_timer > 0
