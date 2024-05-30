extends Node2D
class_name Wagon

@onready var spr = $spr

var wagon_connected_back : Node
var wagon_connected_front : Node

var speed := 0.0
var braking := 0.5

var next_pos := Vector2.ZERO
var last_pos := Vector2.ZERO

@export var connected_to : Node # should be an engine or other wagons

@onready var map : TileMap = get_parent()

func _ready():
	add_to_group("obstacles")
	add_to_group("saving")
	last_pos = position
	
	if connected_to != null:
		next_pos = connected_to.last_pos

func save() -> Dictionary:
	return {
		"filename" 				: get_scene_file_path(),
		"pos_x" 				: position.x, # Vector2 is not supported by JSON
		"pos_y" 				: position.y,
		"last_pos" 				: var_to_str(last_pos),
		"speed" 				: speed,
	}

func load( load_data : Dictionary ):
	position.x 				= load_data["pos_x"]
	position.y 				= load_data["pos_y"]
	last_pos 				= str_to_var(load_data["last_pos"])
	speed 					= load_data["speed"]

func _process(delta):
	if connected_to != null:
		if position.is_equal_approx(next_pos):
			last_pos = next_pos
			next_pos = connected_to.last_pos
		speed = connected_to.speed
	else:
		speed = lerpf(speed, 0, braking * delta)
	
	spr.look_at( next_pos )
	position = position.move_toward(next_pos, speed)
	
	
	
