extends CharacterBody3D
class_name PlayerController

# Components
var state_machine: PlayerStateMachine
var movement: PlayerMovement
var jump: PlayerJump
var slide: PlayerSlide
var visual: PlayerVisual
var rotation: PlayerRotation

# Component Settings
@export_group("Component Settings")
@export var movement_settings: PlayerMovement
@export var jump_settings: PlayerJump
@export var slide_settings: PlayerSlide

# Input Settings
@export_group("Input Settings")
@export var controller_sensitivity: float = 3.0

# Rotation Settings
@export_group("Rotation Settings")
@export var rotation_speed: float = 12.0
@export var use_wind_waker_rotation: bool = true
@export var camera_node_path: NodePath = "../Camera3D"

# Camera reference
var camera: Camera3D

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
	rotation = PlayerRotation.new(self)
	
	# Setup rotation settings
	rotation.rotation_speed = rotation_speed
	
	# Setup visual component
	visual.setup(self)
	
	# Get camera reference safely
	call_deferred("setup_camera")
	
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
	handle_rotation(delta)
	handle_state_machine(delta)
	movement.apply_movement(delta)
	move_and_slide()
	jump.post_movement_update()
	visual.update_visual_for_state(state_machine.current_state)

func get_input():
	movement.get_input()
	jump.get_input()

func handle_rotation(delta: float):
	# Only rotate when there's movement input and not sliding
	if movement.input_direction.length() > 0.1 and state_machine.current_state != PlayerStateMachine.PlayerState.SLIDING:
		# Get camera reference if we don't have one yet
		if not camera:
			camera = find_camera_in_scene()
		
		if use_wind_waker_rotation:
			rotation.update_wind_waker_rotation(delta, movement.input_direction, camera)
		else:
			rotation.update_rotation(delta, movement.input_direction, camera)

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
	# Use player's current facing direction for slide
	var slide_direction = rotation.get_forward_direction()
	slide.start_slide(slide_direction)

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

func get_facing_direction() -> Vector3:
	return rotation.get_forward_direction()

func is_facing_movement_direction() -> bool:
	return rotation.is_facing_movement_direction()

func set_rotation_speed(speed: float):
	rotation.set_rotation_speed(speed)
	rotation_speed = speed

func setup_camera():
	# Try to find camera with different methods
	if not camera_node_path.is_empty():
		# First try to get the node if it's a relative path
		if not camera_node_path.is_absolute():
			var node = get_node_or_null(camera_node_path)
			if node and node is Camera3D:
				camera = node
				return
		
		# If absolute path, try to find from scene root
		var scene_root = get_tree().current_scene
		if scene_root:
			var node = scene_root.get_node_or_null(camera_node_path)
			if node and node is Camera3D:
				camera = node
				return
	
	# Fallback: search for any Camera3D in the scene
	camera = find_camera_in_scene()

func find_camera_in_scene() -> Camera3D:
	# Search in parent nodes first
	var current = get_parent()
	while current:
		if current is Camera3D:
			return current
		# Search children
		for child in current.get_children():
			if child is Camera3D:
				return child
		current = current.get_parent()
	
	# Search in scene root if not found
	var scene_root = get_tree().current_scene
	if scene_root:
		return search_camera_recursive(scene_root)
	
	return null

func search_camera_recursive(node: Node) -> Camera3D:
	if node is Camera3D:
		return node
	
	for child in node.get_children():
		var result = search_camera_recursive(child)
		if result:
			return result
	
	return null
