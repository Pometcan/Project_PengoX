extends Resource
class_name PlayerSlide

# Slide Settings
@export var base_slide_duration: float = 2.0
@export var min_slide_speed: float = 3.0
@export var max_slide_speed: float = 15.0
@export var slide_acceleration: float = 12.0
@export var slide_deceleration: float = 3.0
@export var uphill_deceleration: float = 12.0

# Control Settings
@export var slide_control_strength: float = 2.0
@export var slide_curve_factor: float = 0.3

# Physics Settings  
@export var slope_detection_distance: float = 1.0
@export var momentum_preservation: float = 0.8
@export var min_slope_angle: float = 5.0
@export var slope_slide_threshold: float = 0.15

# Slide variables
var slide_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO
var slide_velocity: Vector3 = Vector3.ZERO
var current_slide_speed: float = 0.0
var is_sliding: bool = false
var initial_speed: float = 0.0
var is_on_slope: bool = false
var current_slope_factor: float = 0.0

var player: CharacterBody3D

signal slide_started()
signal slide_ended()

func _init(player_ref: CharacterBody3D):
	player = player_ref

func start_slide(movement_direction: Vector3):
	slide_timer = base_slide_duration
	is_sliding = true
	
	var horizontal_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
	initial_speed = horizontal_velocity.length()
	
	if movement_direction.length() > 0:
		slide_direction = movement_direction.normalized()
	else:
		slide_direction = -player.transform.basis.z.normalized()
	
	# Start speed
	current_slide_speed = max(initial_speed * momentum_preservation, min_slide_speed)
	slide_velocity = slide_direction * current_slide_speed
	update_slope_status()
	
	slide_started.emit()
	print("Slide started! Initial speed: ", initial_speed, " Slide speed: ", current_slide_speed, " On slope: ", is_on_slope)

func end_slide():
	is_sliding = false
	slide_ended.emit()
	print("Slide ended! Final speed: ", current_slide_speed)

func update_slide(delta: float, _slide_speed: float) -> Vector3:
	update_slope_status()
	
	if is_on_slope:
		slide_timer = base_slide_duration
		print("Downhill slope - continuous sliding, timer reset")
	else:
		slide_timer -= delta
	
	var input_direction = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_direction.length() > 0:
		var input_dir_3d = Vector3(input_direction.x, 0, input_direction.y).normalized()
		slide_direction = slide_direction.slerp(input_dir_3d, slide_control_strength * slide_curve_factor * delta)
	
	# Check slope of floor
	var slope_factor = get_slope_factor()
	current_slope_factor = slope_factor
	
	# Speed change
	var speed_change = 0.0
	if abs(slope_factor) < 0.1:  # Flat floor
		speed_change = -slide_deceleration
		print("Flat ground - decelerating: ", speed_change)
	elif slope_factor > 0.1:  # Downhill floor
		speed_change = slide_acceleration * slope_factor
		print("Downhill (", slope_factor, ") - accelerating: ", speed_change)
	else:  # Uphill floor
		speed_change = -uphill_deceleration * abs(slope_factor)
		print("Uphill (", slope_factor, ") - decelerating: ", speed_change)
	
	# Speed Update
	current_slide_speed = clamp(
		current_slide_speed + speed_change * delta,
		min_slide_speed,
		max_slide_speed
	)
	slide_velocity = slide_direction * current_slide_speed
	return slide_velocity

func update_slope_status():
	var floor_normal = player.get_floor_normal()
	if floor_normal == Vector3.ZERO:
		is_on_slope = false
		return
	
	var slope_angle = acos(clamp(floor_normal.dot(Vector3.UP), -1.0, 1.0))
	var slope_angle_degrees = rad_to_deg(slope_angle)
	
	if slope_angle_degrees > min_slope_angle:
		var slope_factor = get_slope_factor()
		is_on_slope = slope_factor > slope_slide_threshold
	else:
		is_on_slope = false

func get_slope_factor() -> float:
	var floor_normal = player.get_floor_normal()
	if floor_normal == Vector3.ZERO:
		return 0.0
	var slope_angle = acos(clamp(floor_normal.dot(Vector3.UP), -1.0, 1.0))
	if slope_angle < deg_to_rad(min_slope_angle):
		return 0.0
	var floor_slope_direction = Vector3(floor_normal.x, 0, floor_normal.z).normalized()
	var alignment = slide_direction.dot(floor_slope_direction)
	var slope_strength = sin(slope_angle)
	return alignment * slope_strength

func should_end_slide() -> bool:
	# Slide finish
	var time_up = slide_timer <= 0 and not is_on_slope
	var too_slow = current_slide_speed <= min_slide_speed * 0.2
	var crouch_released = not Input.is_action_pressed("crouch")
	var hit_wall = player.is_on_wall()
	
	# slope floor rules
	if is_on_slope:
		var should_end = too_slow or crouch_released or hit_wall
		if should_end:
			if too_slow:
				print("Slope slide ended: Too slow (", current_slide_speed, ")")
			elif crouch_released:
				print("Slope slide ended: Crouch released")
			elif hit_wall:
				print("Slope slide ended: Hit wall")
		return should_end
	else:
		# Flat floor rules
		if time_up:
			print("Slide ended: Time up")
		elif too_slow:
			print("Slide ended: Too slow (", current_slide_speed, ")")
		elif crouch_released:
			print("Slide ended: Crouch released")
		elif hit_wall:
			print("Slide ended: Hit wall")
		
		return time_up or too_slow or crouch_released or hit_wall

func can_start_slide(current_velocity: Vector3) -> bool:
	var horizontal_speed = Vector3(current_velocity.x, 0, current_velocity.z).length()
	return horizontal_speed > min_slide_speed * 0.5

# Debug functions
func get_slide_speed() -> float:
	return current_slide_speed if is_sliding else 0.0

func get_slide_direction() -> Vector3:
	return slide_direction if is_sliding else Vector3.ZERO

func get_slope_info() -> Dictionary:
	return {
		"is_on_slope": is_on_slope,
		"slope_factor": current_slope_factor,
		"slide_timer": slide_timer
	}
