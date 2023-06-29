extends Node

@export_category("Synced")
@export var sync_position : Vector3
@export var sync_velocity : Vector3

@export var look_h = 0.0
@export var look_v = 0.0

@export_category("Internals")
@export var player : CharacterBody3D

var gravity = -32.0
var jump_vel = 12.0
var move_speed = 5.0

var vert_velocity = 0.0
var look_sens = 2.0
var mouse_held

func _ready():
	var is_authority = get_multiplayer_authority() == multiplayer.get_unique_id()
	set_process(is_authority)
	set_physics_process(is_authority)
	set_process_input(is_authority)
	
	player.tag.text = player.username

func _input(event):
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_held else Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			mouse_held = event.pressed
		
	if event is InputEventMouseMotion and mouse_held:
		mouse_move(event)

func _physics_process(delta):
	player_move(delta)

func mouse_move(motion : InputEventMouseMotion):
	# [-tau, +tau]
	look_h = fmod(look_h - motion.relative.x * look_sens * 0.001, TAU);
	# [-pi/2, +pi/2]
	look_v = clampf(look_v - motion.relative.y * look_sens * 0.001, -PI / 2.0, PI / 2.0);

func player_move(delta):
	var move_vector = Input.get_vector("PlayerLeft", "PlayerRight", "PlayerForward", "PlayerBackward").normalized()

	var forward_vector = Vector3.FORWARD.rotated(Vector3.UP, look_h)
	var right_vector = Vector3(forward_vector.z, 0.0, -forward_vector.x)

	vert_velocity = vert_velocity + gravity * delta if not player.is_on_floor() else 0.0

	if Input.is_action_just_pressed("PlayerJump") and player.is_on_floor():
		vert_velocity = jump_vel

	var velocity_vector = \
	right_vector * move_vector.x * move_speed + \
	forward_vector * move_vector.y * move_speed + \
	Vector3.UP * vert_velocity

	player.velocity = player.velocity.lerp(velocity_vector, 16.0 * delta)
	player.move_and_slide()
	sync_velocity = player.velocity
	sync_position = player.position
