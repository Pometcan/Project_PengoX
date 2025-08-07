extends Resource
class_name PlayerVisual

var mesh_instance: MeshInstance3D
var material: StandardMaterial3D

# State color mapping
var state_colors = {
	PlayerStateMachine.PlayerState.IDLE: Color(0.8, 0.8, 0.8),
	PlayerStateMachine.PlayerState.WALKING: Color(1, 1, 1),
	PlayerStateMachine.PlayerState.RUNNING: Color(1, 1, 0),
	PlayerStateMachine.PlayerState.JUMPING: Color(0, 1, 0),
	PlayerStateMachine.PlayerState.FALLING: Color(0, 0, 1),
	PlayerStateMachine.PlayerState.SLIDING: Color(1, 0, 1),
	PlayerStateMachine.PlayerState.CROUCHING: Color(1, 0, 0)
}

func setup(player: CharacterBody3D):
	mesh_instance = player.find_child("MeshInstance3D")
	if not mesh_instance:
		mesh_instance = player.find_child("MeshInstance")
	if not mesh_instance:
		push_error("MeshInstance3D not found!")
		return
	
	setup_material()

func setup_material():
	if not mesh_instance:
		return
		
	material = mesh_instance.get_surface_override_material(0)
	if not material:
		material = StandardMaterial3D.new()
		mesh_instance.set_surface_override_material(0, material)
	else:
		material = material.duplicate()
		mesh_instance.set_surface_override_material(0, material)

func change_material_color(color: Color):
	if material:
		material.albedo_color = color

func update_visual_for_state(state: PlayerStateMachine.PlayerState):
	if state in state_colors:
		change_material_color(state_colors[state])
