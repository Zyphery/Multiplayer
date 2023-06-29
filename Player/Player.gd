extends CharacterBody3D

@export var start_pos : Vector3

@export var id := 1:
	set(value):
		id = value
		$SyncInput.set_multiplayer_authority(value)
@export var username : String

@export var body : Node3D
@export var head : Node3D
@export var camera : Camera3D
@export var input : MultiplayerSynchronizer
@export var tag : Label3D

func _ready():
	if not id == multiplayer.get_unique_id():
		return
	body.visible = false
	camera.current = true
	
	position = start_pos
	input.sync_position = start_pos
	

func _process(delta):
	position = input.sync_position
	velocity = input.sync_velocity
	var body_turn = input.look_h
	head.basis = Basis(Vector3.UP, input.look_h - body_turn) * Basis(Vector3.RIGHT, -input.look_v)
	body.basis = Basis(Vector3.UP, body_turn)
