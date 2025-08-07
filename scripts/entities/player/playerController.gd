extends CharacterBody3D
class_name PlayerController

# Components
var state_machine: PlayerStateMachine
var movement: PlayerMovement
var jump: PlayerJump
var slide: PlayerSlide
var visual: PlayerVisual

# Component Settings
@export_group("Component Settings")
@export var movement_settings: PlayerMovement
@export var jump_settings: PlayerJump
@export var slide_settings: PlayerSlide

# Input Settings
@export_group("Input Settings")
@export var controller_sensitivity: float = 3.0

# Signals
signal state_changed(old_state: PlayerStateMachine.PlayerState, new_state: PlayerStateMachine.PlayerState)
signal landed()
signal jumped()
signal slide_started()
signal slide_ended()

func _ready():
	# Initialize components
	state_machine = PlayerStateMachine.new(self)
	movement = PlayerMovement.new(self)
	jump = PlayerJump.new(self)
	slide = PlayerSlide.new(self)
	visual = PlayerVisual.new()
	
	# Setup visual component
	visual.setup(self)
	
	# Connect signals
	state_machine.state_changed.connect(_on_state_changed)
	jump.jumped.connect(_on_jumped)
	slide.slide_started.connect(_on_slide_started)
	slide.slide_ended.connect(_on_slide_ended)

func _input(event):
	return;

func _physics_process(delta: float) -> void:
	# Update timers
	jump.update_timers(delta)
	
	get_input()
	handle_state_machine(delta)
	movement.apply_movement(delta)
	move_and_slide()
	jump.post_movement_update()
	visual.update_visual_for_state(state_machine.current_state)

func get_input():
	movement.get_input()
	jump.get_input()

func handle_state_machine(delta: float):
	state_machine.update(delta)
	
	match state_machine.current_state:
		PlayerStateMachine.PlayerState.IDLE:
			handle_idle_state()
		PlayerStateMachine.PlayerState.WALKING:
			handle_walking_state()
		PlayerStateMachine.PlayerState.RUNNING:
			handle_running_state()
		PlayerStateMachine.PlayerState.JUMPING:
			handle_jumping_state()
		PlayerStateMachine.PlayerState.FALLING:
			handle_falling_state()
		PlayerStateMachine.PlayerState.SLIDING:
			handle_sliding_state(delta)
		PlayerStateMachine.PlayerState.CROUCHING:
			handle_crouching_state()

func handle_idle_state():
	movement.target_velocity = Vector3.ZERO
	
	# Transitions
	if not is_on_floor():
		state_machine.change_state(PlayerStateMachine.PlayerState.FALLING)
	elif jump.can_jump() and jump.has_jump_input():
		state_machine.change_state(PlayerStateMachine.PlayerState.JUMPING)
	elif Input.is_action_pressed("crouch"):
		state_machine.change_state(PlayerStateMachine.PlayerState.CROUCHING)
	elif movement.input_direction.length() > 0.1:
		if Input.is_action_pressed("run"):
			state_machine.change_state(PlayerStateMachine.PlayerState.RUNNING)
		else:
			state_machine.change_state(PlayerStateMachine.PlayerState.WALKING)

func handle_walking_state():
	movement.set_target_velocity(movement.walk_speed)
	
	# Transitions
	if not is_on_floor():
		state_machine.change_state(PlayerStateMachine.PlayerState.FALLING)
	elif jump.can_jump() and jump.has_jump_input():
		state_machine.change_state(PlayerStateMachine.PlayerState.JUMPING)
	elif Input.is_action_pressed("crouch"):
		if slide.can_start_slide(velocity):
			start_slide()
		else:
			state_machine.change_state(PlayerStateMachine.PlayerState.CROUCHING)
	elif movement.input_direction.length() < 0.1:
		state_machine.change_state(PlayerStateMachine.PlayerState.IDLE)
	elif Input.is_action_pressed("run"):
		state_machine.change_state(PlayerStateMachine.PlayerState.RUNNING)

func handle_running_state():
	movement.set_target_velocity(movement.run_speed)
	
	# Transitions
	if not is_on_floor():
		state_machine.change_state(PlayerStateMachine.PlayerState.FALLING)
	elif jump.can_jump() and jump.has_jump_input():
		state_machine.change_state(PlayerStateMachine.PlayerState.JUMPING)
	elif Input.is_action_pressed("crouch"):
		start_slide()
	elif movement.input_direction.length() < 0.1:
		state_machine.change_state(PlayerStateMachine.PlayerState.IDLE)
	elif not Input.is_action_pressed("run"):
		state_machine.change_state(PlayerStateMachine.PlayerState.WALKING)

func handle_jumping_state():
	# Apply jump
	if state_machine.state_time < 0.1:  # Only on first frame of jump
		jump.perform_jump()
	
	# Air movement
	movement.target_velocity.x = movement.movement_direction.x * movement.current_speed
	movement.target_velocity.z = movement.movement_direction.z * movement.current_speed
	
	# Transitions
	if velocity.y <= 0:
		state_machine.change_state(PlayerStateMachine.PlayerState.FALLING)

func handle_falling_state():
	# Air movement
	movement.target_velocity.x = movement.movement_direction.x * movement.current_speed
	movement.target_velocity.z = movement.movement_direction.z * movement.current_speed
	
	# Transitions
	if is_on_floor():
		state_machine.change_state(PlayerStateMachine.PlayerState.IDLE)
		landed.emit()
	elif jump.can_jump() and jump.has_jump_input() and jump.jumps_remaining > 0:
		state_machine.change_state(PlayerStateMachine.PlayerState.JUMPING)

func handle_sliding_state(delta: float):
	var slide_vel = slide.update_slide(delta, movement.slide_speed)
	movement.target_velocity.x = slide_vel.x
	movement.target_velocity.z = slide_vel.z
	
	# End slide conditions
	if slide.should_end_slide():
		end_slide()

func handle_crouching_state():
	movement.set_target_velocity(movement.crouch_speed)
	
	# Transitions
	if not is_on_floor():
		state_machine.change_state(PlayerStateMachine.PlayerState.FALLING)
	elif not Input.is_action_pressed("crouch"):
		if movement.input_direction.length() > 0.1:
			state_machine.change_state(PlayerStateMachine.PlayerState.WALKING)
		else:
			state_machine.change_state(PlayerStateMachine.PlayerState.IDLE)
	elif jump.can_jump() and jump.has_jump_input():
		state_machine.change_state(PlayerStateMachine.PlayerState.JUMPING)

func start_slide():
	state_machine.change_state(PlayerStateMachine.PlayerState.SLIDING)
	slide.start_slide(movement.movement_direction)

func end_slide():
	slide.end_slide()
	
	if Input.is_action_pressed("crouch"):
		state_machine.change_state(PlayerStateMachine.PlayerState.CROUCHING)
	elif movement.input_direction.length() > 0.1:
		state_machine.change_state(PlayerStateMachine.PlayerState.WALKING)
	else:
		state_machine.change_state(PlayerStateMachine.PlayerState.IDLE)

# Signal handlers
func _on_state_changed(old_state: PlayerStateMachine.PlayerState, new_state: PlayerStateMachine.PlayerState):
	state_changed.emit(old_state, new_state)
	print("State changed: ", PlayerStateMachine.PlayerState.keys()[old_state], " -> ", PlayerStateMachine.PlayerState.keys()[new_state])

func _on_jumped():
	jumped.emit()

func _on_slide_started():
	slide_started.emit()

func _on_slide_ended():
	slide_ended.emit()

# Utility functions
func get_current_state_name() -> String:
	return state_machine.get_current_state_name()

func is_moving() -> bool:
	return movement.is_moving()

func get_horizontal_velocity() -> Vector3:
	return movement.get_horizontal_velocity()

func get_movement_speed() -> float:
	return movement.get_movement_speed()
