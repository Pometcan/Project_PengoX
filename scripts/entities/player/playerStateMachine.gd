extends Resource
class_name PlayerStateMachine

enum PlayerState {
	IDLE,
	WALKING,
	RUNNING,
	JUMPING,
	FALLING,
	SLIDING,
	CROUCHING
}

var current_state: PlayerState = PlayerState.IDLE
var previous_state: PlayerState = PlayerState.IDLE
var state_time: float = 0.0
var player: CharacterBody3D

signal state_changed(old_state: PlayerState, new_state: PlayerState)

func _init(player_ref: CharacterBody3D):
	player = player_ref

func update(delta: float):
	state_time += delta
	
	match current_state:
		PlayerState.IDLE:
			handle_idle_state()
		PlayerState.WALKING:
			handle_walking_state()
		PlayerState.RUNNING:
			handle_running_state()
		PlayerState.JUMPING:
			handle_jumping_state()
		PlayerState.FALLING:
			handle_falling_state()
		PlayerState.SLIDING:
			handle_sliding_state(delta)
		PlayerState.CROUCHING:
			handle_crouching_state()

func change_state(new_state: PlayerState):
	if current_state != new_state:
		previous_state = current_state
		current_state = new_state
		state_time = 0.0
		state_changed.emit(previous_state, current_state)

func get_current_state_name() -> String:
	return PlayerState.keys()[current_state]

# State handlers
func handle_idle_state():
	pass  # Implementation will be handled in PlayerController
	
func handle_walking_state():
	pass
	
func handle_running_state():
	pass
	
func handle_jumping_state():
	pass
	
func handle_falling_state():
	pass
	
func handle_sliding_state(delta: float):
	pass
	
func handle_crouching_state():
	pass
